#! /usr/bin/env dash
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash yq jq ncurses
. ./logging
. ./profiling

set -eu

logger_trace 'util/tomlq-cached.sh'

params="$1"
query="$2"
shift 2

if [ -n "${HOMEKIT_SH_CACHE_TOML:-}" ]; then
    for tomlfile in $*; do
        logger_debug "Using memory cached JSON for $tomlfile"
        ./util/cache_get.sh "$tomlfile" | jq $params "$query"
    done
elif [ -n "${HOMEKIT_SH_CACHE_TOML_DISK:-}" ]; then
    for tomlfile in $*; do
        logger_debug "Using disk cached JSON for $tomlfile"
        jq $params "$query" "/tmp/HOMEKIT_SH_$(./util/cache_mkkey.sh "$tomlfile")"
    done
else
    logger_debug "Using tomlq for $*"
    tomlq $params "$query" $*
fi