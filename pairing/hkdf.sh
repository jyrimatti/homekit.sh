#! /usr/bin/env nix-shell
#! nix-shell --pure --keep LD_LIBRARY_PATH -i dash -I channel:nixos-23.11-small -p dash nix coreutils ncurses openssl
. ./prelude
set -eu

logger_trace 'pairing/hkdf.sh'

salt="$1"
info="$2"

# key in hex is read from stdin

openssl kdf -keylen 32 -kdfopt digest:sha512 -kdfopt salt:"$salt" -kdfopt info:"$info" -kdfopt hexkey:"$(cat)" HKDF | tr -d ":\n"
