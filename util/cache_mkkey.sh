#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash coreutils ncurses
. ./prelude

set -eu

logger_trace 'util/cache_mkkey.sh'

tomlfile="$1"

echo "$tomlfile" | tr -c '[:alnum:]\n' '_'