#! /usr/bin/env python3

import sys
from Crypto.Cipher import ChaCha20_Poly1305

def packNonce(nonce):
    return str.encode(nonce).rjust(12, b"\x00")

def decode(nonce, key, authtag, ciphertext):
    c2a = ChaCha20_Poly1305.new(key=key, nonce=packNonce(nonce))
    return c2a.decrypt_and_verify(ciphertext, authtag)

decoded = decode(sys.argv[1],
                 bytes.fromhex(sys.argv[2]),
                 bytes.fromhex(sys.argv[3]),
                 sys.stdin.buffer.read())
print(decoded.hex())