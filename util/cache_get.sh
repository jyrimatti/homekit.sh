#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash ncurses
. ./prelude

set -eu

# Retrieve cached toml file from environment, or empty string if not found

logger_trace 'util/cache_get.sh'

tomlfile="$1"

eval "echo \"\$HOMEKIT_SH_$(dash ./util/cache_mkkey.sh "$tomlfile")\""