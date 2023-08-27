#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p dash coreutils ncurses
. ./logging
. ./profiling

set -eu

logger_trace 'util/hash.sh'

cksum -a crc | cut -d' ' -f1
