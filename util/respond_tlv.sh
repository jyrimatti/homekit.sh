#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-24.11-small -p nix dash ncurses coreutils
. ./prelude
set -eu

logger_trace 'util/respond_tlv.sh'

status="$1"
responseHex="$2"

if [ "$status" = "000" ]; then
    status=200
fi

contentType="application/pairing+tlv8"
response="$(mktemp "$HOMEKIT_SH_RUNTIME_DIR/homekit.sh_respond_tlv.XXXXXX")"

echo -n "$responseHex" | ./util/hex2bin.sh > "$response"
./util/respond.sh "$status" "" "$contentType" "$(wc -c < "$response")"
cat "$response"
rm "$response"
