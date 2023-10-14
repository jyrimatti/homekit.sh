import { stdout, stderr, env} from "process";
import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import { join } from 'path';

export const enum Colors {
    RED    = "\x1b[91m",
    GREEN  = "\x1b[92m",
    YELLOW = "\x1b[93m",
    GRAY   = "\x1b[97m",
    RESET  = "\x1b[0m"
}

export const enum TLVValues {
    METHOD         = 0x00, // Method to use for pairing.
    IDENTIFIER     = 0x01, // Identifier for authentication.
    SALT           = 0x02, // 16+ bytes of random salt.
    PUBLIC_KEY     = 0x03, // Curve25519, SRP public key, or signed Ed25519 key.
    PROOF          = 0x04, // Ed25519 or SRP proof.
    ENCRYPTED_DATA = 0x05, // Encrypted data with auth tag at end.
    STATE          = 0x06, // State of the pairing process. 1=M1, 2=M2, etc.
    ERROR          = 0x07, // Error code. Must only be present if error code is not 0.
    RETRY_DELAY    = 0x08, // Seconds to delay until retrying a setup code.
    CERTIFICATE    = 0x09, // X.509 Certificate.
    SIGNATURE      = 0x0A, // Ed25519 or Apple Authentication Coprocessor signature.
    PERMISSIONS    = 0x0B, // Bit value describing permissions of the controller being added.
    FRAGMENT_DATA  = 0x0C, // Non-last fragment of data. If length is 0, itʼs an ACK.
    FRAGMENT_LAST  = 0x0D, // Last fragment of data.
    FLAGS          = 0x13, // Pairing Type Flags (32 bit unsigned integer).
    SEPARATOR      = 0x0FF // Zero-length TLV that separates different TLVs in a list.
}

export const enum PairingStates {
    M1 = 0x01,
    M2 = 0x02,
    M3 = 0x03,
    M4 = 0x04,
    M5 = 0x05,
    M6 = 0x06
}

export const enum TLVErrorCode {
    UNKNOWN        = 0x01, // generic error to handle unexpected errors
    AUTHENTICATION = 0x02, // setup code or signature verification failed
    BACKOFF        = 0x03, // client must look at retry delay tlv item and wait that many seconds before retrying
    MAX_PEERS      = 0x04, // server cannot accept any more pairings
    MAX_TRIES      = 0x05, // server reached its maximum number of authentication attempts
    UNAVAILABLE    = 0x06, // server pairing method is unavailable
    BUSY           = 0x07  // server is busy and cannot accept pairing request at this time
}


export function mkStorePath(path: string): void {
    mkdirSync(join(env.HOMEKIT_SH_STORE_DIR || '', path), { recursive: true });
}

export function writeToStore(name: string, data: Buffer): void {
    writeFileSync(join(env.HOMEKIT_SH_STORE_DIR || '', name), data, { flag: 'w' });
}
export function readFromStore(name: string): Buffer {
    return readFileSync(join(env.HOMEKIT_SH_STORE_DIR || '', name));
}

function getLevel() {
    return (env.HOMEKIT_SH_LOGGING_LEVEL || '').toUpperCase();
}

export function log_debug(msg: string): void {
    const level = getLevel();
    if (level != "FATAL" && level != "ERROR" && level != "WARN" && level != "INFO") {
        log("DEBUG", Colors.GRAY, msg);
    }
}
export function log_info(msg: string): void {
    const level = getLevel();
    if (level != "FATAL" && level != "ERROR" && level != "WARN") {
        log("INFO ", Colors.GREEN, msg);
    }
}
export function log_warn(msg: string): void {
    const level = getLevel();
    if (level != "FATAL" && level != "ERROR") {
        log("WARN ", Colors.YELLOW, msg);
    }
}
export function log_error(msg: string): void {
    const level = getLevel();
    if (level != "FATAL") {
        log("ERROR", Colors.RED, msg);
    }
}
function log(level: "DEBUG" | "INFO " | "WARN " | "ERROR", color: Colors, msg: string): void {
    const time = new Date(new Date().getTime() - new Date().getTimezoneOffset()*60000).toISOString().replace('T',' ').slice(0, 19);
    stderr.write(color + time + " " + level + " [" + (env.REMOTE_ADDR || '') + ":" + (env.REMOTE_PORT || '') + "] javascript - " + msg + "\n" + Colors.RESET);
}

export function respondTLV(status: number, tlv: Buffer): void {
    stdout.write("Content-Type: application/pairing+tlv8\r\n");
    stdout.write("Connection: keep-alive\r\n");
    stdout.write("Content-Length: " + tlv.byteLength + "\r\n");
    stdout.write("\r\n");
    stdout.end(tlv);
    if (status != 200) {
        process.exit(0);
    }
}

export function extractMessageAndAuthTag(encryptedData: Buffer): {messageData: Buffer, authTagData: Buffer} {
    const messageData = Buffer.alloc(encryptedData.length - 16);
    const authTagData = Buffer.alloc(16);
    encryptedData.copy(messageData, 0, 0, encryptedData.length - 16);
    encryptedData.copy(authTagData, 0, encryptedData.length - 16, encryptedData.length);
    return { messageData, authTagData };
}
