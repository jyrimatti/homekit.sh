#! /usr/bin/env python3

from socket import error as SocketError
import errno
import socket
import socketserver
import http.server
import struct
import os
import contextlib
import io
import sys
import time
import shutil
import tempfile
import argparse
import platform
import subprocess
from Crypto.Cipher import ChaCha20_Poly1305

METHODS = {
  "GE": "GET",
  "PO": "POST",
  "PU": "PUT",
  "DE": "DELETE",
  "CO": "CONNECT",
  "OP": "OPTIONS",
  "TR": "TRACE",
  "PA": "PATCH"
}

RED    = '\033[91m'
GREEN  = '\033[92m'
YELLOW = '\033[93m'
GRAY   = '\033[97m'
RESET  = '\033[0m'

TRACE = 'TRACE'
DEBUG = 'DEBUG'
INFO  = 'INFO'
WARN  = 'WARN'
ERROR = 'ERROR'
FATAL = 'FATAL'

def packNonce(nonce):
    return struct.pack("Q", nonce).rjust(12, b"\x00")

def cipherIn(sessionStore, count):
    f = open(sessionStore + "/ControllerToAccessoryKey","rb")
    return ChaCha20_Poly1305.new(key=f.read(), nonce=packNonce(count))

def cipherOut(sessionStore, count):
    f = open(sessionStore + "/AccessoryToControllerKey","rb")
    return ChaCha20_Poly1305.new(key=f.read(), nonce=packNonce(count))

class MyHandler(http.server.CGIHTTPRequestHandler):
    cgi_directories = ['/', '/ui']
    protocol_version = 'HTTP/1.1'

    timeout = 0 # non-blocking to allow sending events between requests
    rbufsize = 1 # buffer to allow peeking. Only 1 byte since response body has to remain in the actual stream for CGI to consume
    disable_nagle_algorithm = True # needed?

    in_counts = {}
    out_counts = {}
    conn_activity = {}

    logging_level = INFO

    def __init__(self, request, client_address, server, *, directory = None):
        super().__init__(request, client_address, server, directory = os.fspath('api'))
    
    def is_cgi(self):
        if self.path.endswith(".html") or self.path.endswith(".js") or self.path.endswith(".css") :
            return False
        return super().is_cgi()

    def log_date_time_string(self):
        year, month, day, hh, mm, ss, x, y, z = time.localtime(time.time())
        return "%04d-%02d-%02d %02d:%02d:%02d" % (year, month, day, hh, mm, ss)

    def log(self, level, color, format, *args):
        message = format % args
        sys.stderr.write(color + "%s %05s [%s] - %s\n" %
            (self.log_date_time_string(),
            level,
            self.address_string(),
            message.translate(self._control_char_table)) + RESET)

    def log_debug(self, format, *args):
        if self.logging_level != FATAL and self.logging_level != ERROR and self.logging_level != WARN and self.logging_level != INFO:
            self.log(DEBUG, GRAY, format, *args)

    def log_info(self, format, *args):
        if self.logging_level != FATAL and self.logging_level != ERROR and self.logging_level != WARN:
            self.log(INFO, GREEN, format, *args)
    
    def log_warn(self, format, *args):
        if self.logging_level != FATAL and self.logging_level != ERROR:
            self.log(WARN, YELLOW, format, *args)

    def log_error(self, format, *args):
        if self.logging_level != FATAL:
            self.log(RED, ERROR, format, *args)
    
    def do_PUT(self):
        self.do_POST()

    def parse_request(self) -> bool:
        ret = super().parse_request()
        if "_command" in dir(self) and self._command is not None:
            self.command = self._command
            self._command = None
        return ret
    
    def address_string(self):
        return self.client_address[0] + ":" + str(self.client_address[1])

    def get_session_store(self):
        return 'store/sessions/' + self.address_string()
    
    def handle(self):
        # initialize connection state
        start = time.time()
        os.environ['REMOTE_ADDR'] = str(self.client_address[0])
        os.environ['REMOTE_PORT'] = str(self.client_address[1])
        os.makedirs(self.get_session_store() + "/events")
        self.in_counts[self.get_session_store()] = 0
        self.out_counts[self.get_session_store()] = 0
        self.conn_activity[self.get_session_store()] = start

        # initialize logging level for this connection
        logging=open("./config/logging", 'r')
        self.logging_level = logging.read().upper()
        logging.close()

        try:
            return super().handle()
        finally:
            # clean up connection state
            self.log_info("Removing session %s after %i seconds, %i idle seconds", self.get_session_store(), time.time() - start, time.time() - self.conn_activity[self.get_session_store()])
            del self.in_counts[self.get_session_store()]
            del self.out_counts[self.get_session_store()]
            shutil.rmtree(self.get_session_store(), ignore_errors=True)

    def handle_one_request(self):
        try:
            if len(self.rfile.peek(1)[:1]) == 0:
                # no data available -> send pending events and retry
                self.handle_events()
                time.sleep(1)
                return
        except SocketError as e:
            if e.errno == errno.ECONNRESET:
                self.log_error("Connection closed by the other end (ECONNRESET)")
                self.close_connection = True
                return
            else:
                raise
        self.conn_activity[self.get_session_store()] = time.time()
        
        startBytes = self.rfile.read(2)[:2]
        start = str(startBytes, 'iso-8859-1')

        if start in METHODS:
            self._command = METHODS[start]
            self.log_debug("Regular HTTP request: %s", self._command)
            os.environ['REQUEST_TYPE'] = "regular"
            ret = super().handle_one_request()
            self.log_debug("Finished regular HTTP request, headers: %s", self.headers)
            self.wfile.flush()
            return ret
        
        elif len(startBytes) == 0:
            self.log_debug("Empty HTTP request?")
            ret = super().handle_one_request()
            self.log_debug("Finished empty HTTP request, headers: %s", self.headers)
            self.wfile.flush()
            return ret
        
        else:
            assert len(startBytes) == 2
            text = self.decodeFromBlocks(startBytes, self.rfile)
            self.log_debug("Encrypted request in plain text: %s", str(text, 'utf-8'))
            os.environ['REQUEST_TYPE'] = "encrypted"
            
            # replace streams with temp files
            original_rfile = self.rfile
            original_wfile = self.wfile
            self.rfile = tempfile.TemporaryFile(buffering=0) # doesn't work with buffering
            self.wfile = tempfile.NamedTemporaryFile()

            try:
                # write decoded request to the temporary rfile
                self.rfile.write(text)
                self.rfile.flush()
                self.rfile.seek(0)

                # handle request
                start = time.time()
                ret = super().handle_one_request()
                end = time.time() - start

                response = open(self.wfile.name, "rb")
            finally:
                # restore original streams
                self.rfile = original_rfile
                self.wfile = original_wfile
            
            # encode response to original wfile
            resp = str(response.read(), "utf-8")
            while resp.startswith("HTTP/1.1 200 Script output follows\r\n") or resp.startswith("Server:") or resp.startswith("Date:"):
                resp = resp[resp.find('\r\n')+2:]
            #resp = resp.replace("\n", "\r\n")
            bytes = self.encodeToBlocks(resp.encode('utf-8')).getvalue()
            
            if end >= 10:
                self.log_error("Request to %s took %s seconds. Total encoded response length: %s, response: %s", self.path, str(end), str(len(bytes)), resp)
            elif end >= 7:
                self.log_warn("Request to %s took %s seconds. Total encoded response length: %s, response: %s", self.path, str(end), str(len(bytes)), resp)
            else:
                self.log_debug("Request to %s took %s seconds. Total encoded response length: %s, response: %s", self.path, str(end), str(len(bytes)), resp)
            
            self.wfile.write(bytes)
            self.wfile.flush()

            return ret
    
    def handle_events(self):
        proc=subprocess.run(['./util/events_send.sh'], capture_output=True)
        stdout=proc.stdout
        stderr=proc.stderr
        if (len(stderr) > 0):
            sys.stderr.write(str(stderr, 'utf-8'))
        if len(stdout) > 0:
            resp = str(stdout, 'utf-8')
            #resp = resp.replace("\n", "\r\n")
            bytes = self.encodeToBlocks(stdout).getvalue()
            self.log_info("Sending event with total encoded response length %s: %s", str(len(bytes)), resp)
            self.wfile.write(bytes)
            self.wfile.flush()

    def decodeFromBlocks(self, datalength, data):
        ret = b''
        # TODO: incomplete frames?
        datalengthInt = struct.unpack("H", datalength)[0]
        while datalengthInt > 0:
            ciphertext    = data.read(datalengthInt)
            tag           = data.read(16)
            
            c2a = cipherIn(self.get_session_store(), self.in_counts[self.get_session_store()])
            self.in_counts[self.get_session_store()] += 1
            
            c2a.update(datalength)
            if len(tag) == 0:
                ret += c2a.decrypt(ciphertext)
            else:
                ret += c2a.decrypt_and_verify(ciphertext, tag)
            
            datalength = data.read(2)
            if datalength is None or len(datalength) == 0:
                datalengthInt = 0
            else: 
                datalengthInt = struct.unpack("H", datalength[:2])[0]

        return ret

    def encodeToBlocks(self, data):
        ret = io.BytesIO()
        offset = 0
        total = len(data)
        while offset < total:
            length = min(total - offset, 1024)
            block = bytes(data[offset : offset + length])
            
            a2c = cipherOut(self.get_session_store(), self.out_counts[self.get_session_store()])
            self.out_counts[self.get_session_store()] += 1
            a2c.update(struct.pack("H", length))
            (ciphertext,digest) = a2c.encrypt_and_digest(block)

            offset += length
            self.log_debug("Got ciphertext/digest of length: %s/%s", str(len(ciphertext)), str(len(digest)))
            
            ret.write(struct.pack("H", len(ciphertext)))
            ret.write(ciphertext)
            ret.write(digest)
        return ret

# Use a forking server (instead of threading) to allow specifying different environment variables for each connection
class ForkingHTTPServer(socketserver.ForkingMixIn, http.server.HTTPServer):
    pass

#class DualStackServer(ForkingHTTPServer):
#    def server_bind(self):
#        with contextlib.suppress(Exception):
#            self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
#        return super().server_bind()
#
#    def finish_request(self, request, client_address):
#        self.RequestHandlerClass(request, client_address, self)
        
#def _get_best_family(*address):
#    infos = socket.getaddrinfo(*address, type=socket.SOCK_STREAM, flags=socket.AI_PASSIVE)
#    family, _, _, _, sockaddr = next(iter(infos))
#    return family, sockaddr

parser = argparse.ArgumentParser()
parser.add_argument('port', default=8000, type=int, nargs='?', help='bind to this port ''(default: %(default)s)')
args = parser.parse_args()
#DualStackServer.address_family, addr = _get_best_family('', args.port)

with ForkingHTTPServer(('', args.port), MyHandler) as httpd:
    host, port = httpd.socket.getsockname()[:2]
    url_host = f'[{host}]' if ':' in host else host
    print(
        f"Serving HTTP on {host} port {port} "
        f"(http://{url_host}:{port}/) ..."
    )
    httpd.serve_forever()
