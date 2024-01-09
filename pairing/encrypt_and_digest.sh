#!/usr/bin/env python3

import sys
from Crypto.Cipher import ChaCha20_Poly1305

def packNonce(nonce):
    return str.encode(nonce).rjust(12, b"\x00")

def encode(nonce, key, message):
    c2a = ChaCha20_Poly1305.new(key=key, nonce=packNonce(nonce))
    [msg,authtag] = c2a.encrypt_and_digest(message)
    return (msg+authtag)

encoded = encode(sys.argv[1],
                 bytes.fromhex(sys.argv[2]),
                 bytes.fromhex(sys.stdin.read()))
print(encoded.hex(), end="")