#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-24.11-small -p nix dash yq jq ncurses
. ./prelude

set -eu

logger_trace 'util/services_grouped_by_type.sh'

tomlfile="$1"

dash ./util/tomlq-cached.sh -c '.services | group_by(.type) | .[]' "$tomlfile"