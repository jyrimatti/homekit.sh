#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash nix coreutils ncurses "pkgs.callPackage ./wolfclu.nix {}"
. ./prefs
. ./log/logging
. ./profiling
set -eu

pub="$1"  # file for public key
priv="$2" # file for private key or '-' for stdout as hex

tmpfile="$(mktemp "$HOMEKIT_SH_RUNTIME_DIR/homekit.sh_generate_keypair.XXXXXX")"
wolfssl -genkey ed25519 -out "$tmpfile"
mv "$tmpfile.pub" "$pub"
if [ "$priv" = '-' ]; then
    dash ./util/bin2hex.sh < "$tmpfile.priv"
else
    mv "$tmpfile.priv" "$priv"
fi