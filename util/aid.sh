#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash yq jq ncurses
. ./logging
. ./profiling

set -eu

# use Accessory Instance ID from toml file if provided, or hash the file path

logger_trace 'util/aid.sh'

tomlfile="$1"

dash ./util/tomlq-cached.sh -ce '.aid // empty' "$tomlfile" || { echo "$tomlfile" | dash ./util/hash.sh; }