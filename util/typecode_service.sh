#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash yq jq
. ./logging
. ./profiling

set -eu

logger_trace 'util/typecode_service.sh'

type="$1"

./util/tomlq-cached.sh -cre ".$type.type" ./config/services/*.toml
