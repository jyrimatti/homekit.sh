#! /usr/bin/env nix-shell
#! nix-shell --pure -i dash -I channel:nixos-23.11-small -p dash nix coreutils xxd ncurses openssl
#. ./prefs
#. ./log/logging
#. ./profiling
set -eu

pub="$1"  # file for public key
priv="$2" # file for private key or '-' for stdout as hex

tmpfile="$(mktemp "${HOMEKIT_SH_RUNTIME_DIR:-/tmp}/homekit.sh_generate_keypair.XXXXXX")"
tmpfile2="$(mktemp "${HOMEKIT_SH_RUNTIME_DIR:-/tmp}/homekit.sh_generate_keypair.XXXXXX")"
tmpfile3="$(mktemp "${HOMEKIT_SH_RUNTIME_DIR:-/tmp}/homekit.sh_generate_keypair.XXXXXX")"
openssl genpkey -algorithm ed25519 -out "$tmpfile"

openssl pkey -in "$tmpfile" -outform der -out "$tmpfile2" -pubout 
openssl pkey -in "$tmpfile" -outform der -out "$tmpfile3"
xxd -plain -cols 99 -s -32 "$tmpfile2" | xxd -r -p > "$pub"
if [ "$priv" = '-' ]; then
    xxd -plain -cols 99 -s -32 "$tmpfile3" | tr -d '\n'
else
    xxd -plain -cols 99 -s -32 "$tmpfile3" | xxd -r -p > "$priv"
fi
