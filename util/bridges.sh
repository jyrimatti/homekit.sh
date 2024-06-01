#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash yq jq ncurses
. ./prelude

set -eu

logger_trace 'util/bridges.sh'

find "$HOMEKIT_SH_ACCESSORIES_DIR" -maxdepth 3 -name '*.toml' \
    | xargs -n1 dash ./util/tomlq-cached.sh -re '[.port // empty, .bridge // empty, .username // empty] | @tsv' \
    | sort \
    | uniq
