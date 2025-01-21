#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-24.11-small -p dash xxd
. ./prelude

set -eu

logger_trace 'util/hex2bin.sh'

xxd -r -p
