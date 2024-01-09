#!/usr/bin/env python3

from nacl.bindings.crypto_box import crypto_box_keypair
import sys
from io import open

[private_key,public_key] = crypto_box_keypair()

priv=open(sys.argv[1], 'wb')
priv.write(private_key)
print(public_key.hex(), end="")
