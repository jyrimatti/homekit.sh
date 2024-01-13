#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash jq xxd
. ./prefs
. ./log/logging
. ./profiling
set -eu

logger_trace 'pairing/pair_setup_m1.sh'

