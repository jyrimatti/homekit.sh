#! /usr/bin/env nix-shell
#! nix-shell --pure -i dash -I channel:nixos-23.11-small -p dash nix "pkgs.callPackage ./wolfclu.nix {}"
set -eu

inkey="$1"   # filename for key
sig="$2" # signature, encoded as hex

# reads input data from stdin, encoded as hex

sigfile="$(mktemp "$HOMEKIT_SH_RUNTIME_DIR/homekit.sh_verify.XXXXXX")"
echo -n "$sig" | dash ./util/hex2bin.sh > "$sigfile"

tmpfile="$(mktemp "$HOMEKIT_SH_RUNTIME_DIR/homekit.sh_verify.XXXXXX")"
dash ./util/hex2bin.sh > "$tmpfile"
wolfssl -ed25519 -verify -inkey "$inkey" -in "$tmpfile" -sigfile "$sigfile" -pubin