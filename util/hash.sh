#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash coreutils ncurses
. ./prelude

set -eu

logger_trace 'util/hash.sh'

ret="$(cksum -a crc "${1:--}")"
echo "${ret%% *}" # return the part before the first space
