#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -I channel:nixos-23.05-small -p nix yq yajsv
set -euo pipefail
PS4='+ $(date "+%T.%3N ($LINENO) ")'

tomlfile=$1

tmpfile=$(mktemp /tmp/homekit.sh_generate-accessory.XXXXXX.json)
tomlq < "$tomlfile" > "$tmpfile"

# validate
yajsv -q -s ./accessory.schema.json "$tmpfile" | sed "s#$tmpfile#$tomlfile#" >&2

cat "$tmpfile"