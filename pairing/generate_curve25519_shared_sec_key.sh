#! /usr/bin/env python3

from nacl.bindings.crypto_scalarmult import crypto_scalarmult
import sys
from io import open

key1=bytes.fromhex(sys.argv[1])
key2=bytes.fromhex(sys.argv[2])

sharedSecret = crypto_scalarmult(key1, key2)

print(sharedSecret.hex())
