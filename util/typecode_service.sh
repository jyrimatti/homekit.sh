#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash yq jq ncurses
. ./logging
. ./profiling

set -eu

logger_trace 'util/typecode_service.sh'

type="$1"

if [ -n "${BETA:-}" ]; then
    ./util/tomlq-cached.sh -ren "first(inputs | select(.$type)).$type.type" ./config/services/*.toml
else
    ./util/tomlq-cached.sh -re ".$type.type" ./config/services/*.toml
fi
