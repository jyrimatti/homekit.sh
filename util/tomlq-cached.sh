#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash yq jq ncurses
. ./prefs
. ./log/logging_no_exit_trap
. ./profiling
set -eu

logger_trace 'util/tomlq-cached.sh'

params="$1"
query="$2"
shift 2

if [ "${HOMEKIT_SH_CACHE_TOML_ENV:-false}" = "true" ]; then
    for tomlfile in $*; do
        logger_debug "Using env cached JSON for $tomlfile"
        dash ./util/cache_get.sh "$tomlfile"
    done | jq $params "$query"
elif [ "${HOMEKIT_SH_CACHE_TOML_DISK:-false}" = "true" ]; then
    sessionCachePath="$HOMEKIT_SH_RUNTIME_DIR/sessions/$REMOTE_ADDR:$REMOTE_PORT/cache"
    for tomlfile in $*; do
        logger_debug "Using disk cached JSON for $tomlfile"
        cat $sessionCachePath/$tomlfile
    done | jq $params "$query"
else
    logger_debug "Using tomlq for $*"
    tomlq $params "$query" $*
fi