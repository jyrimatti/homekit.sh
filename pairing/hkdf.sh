#! /usr/bin/env nix-shell
#! nix-shell --pure -i dash -I channel:nixos-23.11-small -p dash nix coreutils ncurses openssl
#. ./prefs
#. ./log/logging
#. ./profiling
set -eu

salt="$1"
info="$2"

# key in hex is reasd from stdin

openssl kdf -keylen 32 -kdfopt digest:sha512 -kdfopt salt:"$salt" -kdfopt info:"$info" -kdfopt hexkey:"$(cat)" HKDF | tr -d ":\n"
