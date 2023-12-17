#! /usr/bin/env nix-shell
#! nix-shell -i python -I channel:nixos-23.11-small -p python3Packages.tlv8

import sys
import os
import tlv8

structure = {
    0: tlv8.DataType.INTEGER,
    1: tlv8.DataType.STRING,
    2: tlv8.DataType.BYTES,
    3: tlv8.DataType.BYTES,
    4: tlv8.DataType.BYTES,
    5: tlv8.DataType.BYTES,
    6: tlv8.DataType.INTEGER,
    7: tlv8.DataType.INTEGER,
    8: tlv8.DataType.INTEGER,
    9: tlv8.DataType.BYTES,
    10: tlv8.DataType.BYTES,
    11: tlv8.DataType.INTEGER,
    12: tlv8.DataType.BYTES,
    13: tlv8.DataType.BYTES,
    19: tlv8.DataType.INTEGER,
    255: tlv8.DataType.AUTODETECT
}

print(tlv8.decode(sys.stdin.buffer.read(int(os.environ.get('CONTENT_LENGTH', '0'))), structure))