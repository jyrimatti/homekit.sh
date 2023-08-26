#! /usr/bin/env dash
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash yq jq
. ./logging
. ./profiling

set -eu

logger_trace 'util/tomlq_cached.sh'

params="$1"
query="$2"
shift 2

for tomlfile in $*; do
    {
        {
            ./util/cache_get.sh "$tomlfile" && logger_debug "Using cached JSON for $tomlfile"
        } || {
            tomlq -c '' "$tomlfile" && logger_debug "Using tomlq for $tomlfile"
        }
    } | jq $params "$query"
done