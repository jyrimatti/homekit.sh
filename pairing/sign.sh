#! /usr/bin/env nix-shell
#! nix-shell --pure -i dash -I channel:nixos-23.11-small -p dash coreutils nix "pkgs.callPackage ./wolfclu.nix {}"
. ./prefs
. ./log/logging
. ./profiling
set -eu

logger_trace 'pairing/sign.sh'

inkey="$1" # filename for key

# reads input data from stdin, encoded as hex
# writes signature to stdout, encoded as hex

outfile="$(mktemp "$HOMEKIT_SH_RUNTIME_DIR/homekit.sh_sign.XXXXXX")" # segfaults of no -out parameter is given...
infile="$(mktemp "$HOMEKIT_SH_RUNTIME_DIR/homekit.sh_sign.XXXXXX")"
./util/hex2bin.sh > "$infile"
wolfssl -ed25519 -sign -inkey "$inkey" -in "$infile" -out "$outfile"
cat "$outfile" | ./util/bin2hex.sh
