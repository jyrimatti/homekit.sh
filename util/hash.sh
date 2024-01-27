#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash coreutils ncurses
. ./prefs
. ./log/logging
. ./profiling

set -eu

logger_trace 'util/hash.sh'

file="${1:--}"

cksum -a crc "$file" | cut -d' ' -f1
