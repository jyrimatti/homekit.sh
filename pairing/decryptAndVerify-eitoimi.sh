#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash nix openssl
set -eu

in="$1"
out="$2"
key="$3"
pass="$4"

openssl enc -ChaCha20 -d -in "$in" -out "$out" -K "$(od -A n -v -t x1 < "$key" | tr -d ' \n')" -pass "pass:$pass" -pbkdf2 -nosalt | od -A n -v -t x1 | tr -d ' \n'
