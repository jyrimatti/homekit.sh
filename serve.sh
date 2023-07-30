#! /usr/bin/env python3

import socketserver
import http.server
import struct
import os
import io
import time
import shutil
import tempfile
import argparse
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

def packNonce(nonce):
    return struct.pack("Q", nonce).rjust(12, b"\x00")

def cipherIn(sessionStore, count):
    f = open(sessionStore + "/ControllerToAccessoryKey","rb")
    return ChaCha20_Poly1305.new(key=f.read(), nonce=packNonce(count))

def cipherOut(sessionStore, count):
    f = open(sessionStore + "/AccessoryToControllerKey","rb")
    return ChaCha20_Poly1305.new(key=f.read(), nonce=packNonce(count))

class MyHandler(http.server.CGIHTTPRequestHandler):
    cgi_directories = ['/']
    protocol_version = 'HTTP/1.1'

    timeout = 0 # non-blocking to allow sending events between requests
    rbufsize = 1 # buffer to allow peeking. Only 1 byte since response body has to remain in the actual stream for CGI to consume
    disable_nagle_algorithm = True # needed?

    in_counts = {}
    out_counts = {}

    def __init__(self, request, client_address, server, *, directory = None):
        super().__init__(request, client_address, server, directory = os.fspath('api'))

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
        os.environ['REMOTE_PORT'] = str(self.client_address[1])
        os.makedirs(self.get_session_store() + "/events")
        self.in_counts[self.get_session_store()] = 0
        self.out_counts[self.get_session_store()] = 0

        try:
            return super().handle()
        finally:
            # clean up connection state
            self.log_message("Removing session %s", self.get_session_store())
            del self.in_counts[self.get_session_store()]
            del self.out_counts[self.get_session_store()]
            shutil.rmtree(self.get_session_store(), ignore_errors=True)

    def handle_one_request(self):
        self.log_message("Waiting for a request...")

        if len(self.rfile.peek(1)[:1]) == 0:
            # no data available -> send pending events and retry
            self.handle_events()
            time.sleep(1)
            return

        startBytes = self.rfile.read(2)[:2]
        start = str(startBytes, 'iso-8859-1')

        if start in METHODS:
            self._command = METHODS[start]
            self.log_message("Regular HTTP request: %s", self._command)
            os.environ['REQUEST_TYPE'] = "regular"
            return super().handle_one_request()
        
        elif len(startBytes) == 0:
            self.log_message("Empty HTTP request?")
            return super().handle_one_request()
        
        else:
            assert len(startBytes) == 2
            text = self.decodeFromBlocks(startBytes, self.rfile)
            self.log_message("Encrypted request in plain text: %s", str(text))
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
            bytes = self.encodeToBlocks(response.read()).getvalue()
            self.log_message("Request to %s took %s seconds. Total encoded response length: %s", self.path, str(end), str(len(bytes)))
            self.wfile.write(bytes)
            self.wfile.flush()

            return ret
    
    def handle_events(self):
        process_out = tempfile.NamedTemporaryFile()
        subprocess.call(['sh', './util/events_send.sh'], stdout = process_out)
        f = open(process_out.name, "rb")
        b = io.BytesIO()
        for line in f:
            if str(line, 'iso-8859-1').startswith('EVENT/1.0'):
                self.send_if_not_empty(b)
                b = io.BytesIO()
            b.write(line)
        self.send_if_not_empty(b)
    
    def send_if_not_empty(self, b):
        if len(b.getbuffer()) > 0:
            raw = b.getvalue()
            encoded = self.encodeToBlocks(raw).getvalue()
            self.log_message("Sending event with total encoded response length %s: %a", str(len(encoded)), str(raw, 'utf-8'))
            self.wfile.write(encoded)
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
            if datalength is None:
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
            self.log_message("Got ciphertext/digest of length: %s/%s", str(len(ciphertext)), str(len(digest)))
            
            ret.write(struct.pack("H", len(ciphertext)))
            ret.write(ciphertext)
            ret.write(digest)
        return ret

parser = argparse.ArgumentParser()
parser.add_argument('port', default=8000, type=int, nargs='?', help='bind to this port ''(default: %(default)s)')
args = parser.parse_args()

# Use a forking server (instead of threading) to allow specifying different environment variables for each connection
class ForkingHTTPServer(socketserver.ForkingMixIn, http.server.HTTPServer):
    pass

with ForkingHTTPServer(("", args.port), MyHandler) as httpd:
    print("serving at port", args.port)
    httpd.serve_forever()
