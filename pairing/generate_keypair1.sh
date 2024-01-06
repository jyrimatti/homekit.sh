#! /usr/bin/env nix-shell
#! nix-shell --pure -i dash -I channel:nixos-23.11-small -p dash nix coreutils ncurses "pkgs.callPackage ./wolfclu.nix {}"
#. ./prefs
#. ./log/logging
#. ./profiling
set -eu

pub="$1"  # file for public key
priv="$2" # file for private key or '-' for stdout as hex

tmpfile="$(mktemp "${HOMEKIT_SH_RUNTIME_DIR:-/tmp}/homekit.sh_generate_keypair.XXXXXX")"
wolfssl -genkey ed25519 -out "$tmpfile"
mv "$tmpfile.pub" "$pub"
if [ "$priv" = '-' ]; then
    od -A n -v -t x1 < "$tmpfile.priv" | tr -d ' \n'
    rm "$tmpfile.priv"
else
    mv "$tmpfile.priv" "$priv"
fi