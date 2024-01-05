#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash nix "pkgs.callPackage ../wolfclu.nix {}"
set -eu

inkey="$1"   # filename for key
sigfile="$2" # filename for signature

# reads input data from stdin

tmpfile="$(mktemp "${HOMEKIT_SH_RUNTIME_DIR:-/tmp}/homekit.sh_verify.XXXXXX")"
cat > "$tmpfile"
wolfssl -ed25519 -verify -inkey "$inkey" -in "$tmpfile" -sigfile "$sigfile" -pubin
