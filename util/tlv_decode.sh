#!/usr/bin/env python3

import sys
import tlv8

structure = {
    0: tlv8.DataType.INTEGER,
    1: tlv8.DataType.BYTES,
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

def decode_data(type_id, data):
    if structure[type_id] == tlv8.DataType.BYTES:
        return '"' + data.hex() + '"'
    elif structure[type_id] == tlv8.DataType.STRING:
        return '"' + data + '"'
    else:
        return str(data)

input = sys.stdin.read()
tlv = tlv8.decode(bytes.fromhex(input), structure)
print("{", ','.join(['"' + str(entry.type_id) + '": ' + decode_data(entry.type_id, entry.data) for entry in tlv]), "}", end="")