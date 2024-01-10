#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash xxd
. ./prefs
. ./log/logging
. ./profiling

set -eu

logger_trace 'util/bin2hex.sh'

xxd -p -c0