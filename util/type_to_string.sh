#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash yq jq ncurses
. ./logging
. ./profiling

set -eu

logger_trace 'util/type_to_string.sh'

type="$1"

dash ./util/tomlq-cached.sh -rn "first(inputs | select(.[] | .type == \"$type\") | keys[0])" ./config/services/*.toml ./config/characteristics/*.toml

