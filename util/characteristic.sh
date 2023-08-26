#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash yq jq
. ./logging
. ./profiling

set -eu

logger_trace 'util/characteristic.sh'

name="$1"

./util/tomlq-cached.sh -ce "$name" ./config/characteristics/*.toml

