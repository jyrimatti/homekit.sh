#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash yq jq ncurses
. ./prefs
. ./log/logging
. ./profiling

set -eu

logger_trace 'util/characteristic.sh'

IFS=,
dash ./util/tomlq-cached.sh -ce "$*" ./config/characteristics/*.toml
