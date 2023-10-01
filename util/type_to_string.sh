#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash yq jq ncurses sqlite
. ./logging
. ./profiling

set -eu

if [ "$LOGGING_LEVEL" = 'TRACE' ]; then
    # Skip this for tracing, since takes too much time
    echo '?'
    exit 0
fi

logger_trace 'util/type_to_string.sh'

type="$1"

if [ -e "${HOMEKIT_SH_CACHE_TOML_SQLITE:-}" ]; then
    logger_debug 'Using SQLite cached services and characteristics'
    sqlite3 "$HOMEKIT_SH_CACHE_TOML_SQLITE" "select typeName from services where typeCode='$type' union select typeName from characteristics where typeCode='$type' limit 1"
else
    dash ./util/tomlq-cached.sh -rn "first(inputs | select(.[] | .type == \"$type\") | keys[0])" ./config/services/*.toml ./config/characteristics/*.toml
fi
