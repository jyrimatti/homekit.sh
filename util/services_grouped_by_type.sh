#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash yq jq ncurses
. ./prefs
. ./log/logging
. ./profiling

set -eu

logger_trace 'util/services_grouped_by_type.sh'

tomlfile="$1"

dash ./util/tomlq-cached.sh -c '.services | group_by(.type) | .[]' "$tomlfile"