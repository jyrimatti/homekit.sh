#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p dash coreutils ncurses
. ./prefs
. ./logging
. ./profiling

set -eu

logger_trace 'util/cache_mkkey.sh'

tomlfile="$1"

echo "$tomlfile" | tr -c '[:alnum:]\n' '_'