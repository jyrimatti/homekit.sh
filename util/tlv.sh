#!/bin/sh

export TLV_METHOD=0         # Method to use for pairing.
export TLV_IDENTIFIER=1     # Identifier for authentication.
export TLV_SALT=2           # 16+ bytes of random salt.
export TLV_PUBLIC_KEY=3     # Curve25519, SRP public key, or signed Ed25519 key.
export TLV_PROOF=4          # Ed25519 or SRP proof.
export TLV_ENCRYPTED_DATA=5 # Encrypted data with auth tag at end.
export TLV_STATE=6          # State of the pairing process. 1=M1, 2=M2, etc.
export TLV_ERROR=7          # Error code. Must only be present if error code is not 0.
export TLV_RETRY_DELAY=8    # Seconds to delay until retrying a setup code.
export TLV_CERTIFICATE=9    # X.509 Certificate.
export TLV_SIGNATURE=10     # Ed25519 or Apple Authentication Coprocessor signature.
export TLV_PERMISSIONS=11   # Bit value describing permissions of the controller being added.
export TLV_FRAGMENT_DATA=12 # Non-last fragment of data. If length is 0, itʼs an ACK.
export TLV_FRAGMENT_LAST=13 # Last fragment of data.
export TLV_FLAGS=19         # Pairing Type Flags (32 bit unsigned integer).
export TLV_SEPARATOR=255    # Zero-length TLV that separates different TLVs in a list.

export TLV_M1=1
export TLV_M2=2
export TLV_M3=3
export TLV_M4=4
export TLV_M5=5
export TLV_M6=6

export TLV_ERROR_UNKNOWN=1,        # generic error to handle unexpected errors
export TLV_ERROR_AUTHENTICATION=2, # setup code or signature verification failed
export TLV_ERROR_BACKOFF=3,        # client must look at retry delay tlv item and wait that many seconds before retrying
export TLV_ERROR_MAX_PEERS=4,      # server cannot accept any more pairings
export TLV_ERROR_MAX_TRIES=5,      # server reached its maximum number of authentication attempts
export TLV_ERROR_UNAVAILABLE=6,    # server pairing method is unavailable
export TLV_ERROR_BUSY=7            # server is busy and cannot accept pairing request at this time