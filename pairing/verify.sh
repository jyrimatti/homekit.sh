#! /usr/bin/env nix-shell
#! nix-shell --pure -i dash -I channel:nixos-23.11-small -p dash nix "pkgs.callPackage ./wolfclu.nix {}"
set -eu

inkey="$1"   # filename for key
sigfile="$2" # filename for signature

# reads input data from stdin, encoded as hex

tmpfile="$(mktemp "$HOMEKIT_SH_RUNTIME_DIR/homekit.sh_verify.XXXXXX")"
dash ./util/hex2bin.sh > "$tmpfile"
wolfssl -ed25519 -verify -inkey "$inkey" -in "$tmpfile" -sigfile "$sigfile" -pubin
