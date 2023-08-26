#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash yq jq
. ./logging
. ./profiling

set -eu

logger_trace 'util/services.sh'

aid="$1"

tomlfile=$(./util/accessory.sh "$aid")
./util/tomlq-cached.sh -c '.services | .[]' "$tomlfile"