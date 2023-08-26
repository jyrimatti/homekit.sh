#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash yq jq
. ./logging
. ./profiling

set -eu

logger_trace 'util/type_to_string.sh'

type="$1"

./util/tomlq-cached.sh -re "to_entries | map(select(.value.type == \"$type\")) | .[].key" ./config/services/*.toml ./config/characteristics/*.toml

