#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-24.11-small -p nix dash yq jq ncurses
. ./prelude

set -eu

logger_trace 'util/bridges.sh'

modifiedLastMinutes="${1:-}"
if [ "$modifiedLastMinutes" != "" ]; then
    modifiedLastMinutes="-mmin -$modifiedLastMinutes"
fi

find "$HOMEKIT_SH_ACCESSORIES_DIR" -maxdepth 3 -name '*.toml' $modifiedLastMinutes \
    | xargs -n1 dash ./util/tomlq-cached.sh -re '[.port // empty, .bridge // empty, .username // empty] | @tsv' \
    | sort \
    | uniq
