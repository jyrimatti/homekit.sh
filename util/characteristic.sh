#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash yq jq
. ./logging
. ./profiling

set -eu

logger_trace 'util/characteristic.sh'

IFS=,
if [ -n "${BETA:-}" ]; then
    ./util/tomlq-cached.sh -cen "limit($#; inputs | $*)" ./config/characteristics/*.toml
else
    ./util/tomlq-cached.sh -ce "$*" ./config/characteristics/*.toml
fi
