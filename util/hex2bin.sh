#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash xxd
. ./prefs
. ./log/logging
. ./profiling

set -eu

logger_trace 'util/hex2bin.sh'

xxd -r -p
