#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash yq jq ncurses sqlite
. ./prefs
. ./log/logging
. ./profiling
set -eu

logger_trace 'util/typecode_service.sh'

type="$1"

if [ "${HOMEKIT_SH_CACHE_TOML_FS:-false}" = "true" ]; then
    logger_debug 'Using FS cached services'
    for toml in ./config/services/*; do
        file="$HOMEKIT_SH_CACHE_DIR/$(dash ./util/hash.sh "$toml")/$type/type"
        if [ -f "$file" ]; then
            cat "$file"
            exit 0;
        fi
    done
elif [ -e "${HOMEKIT_SH_CACHE_TOML_SQLITE:-}" ]; then
    logger_debug 'Using SQLite cached services'
    sqlite3 -readonly "$HOMEKIT_SH_CACHE_TOML_SQLITE" "select typeCode from services where typeName='$type'"
else
    dash ./util/tomlq-cached.sh -ren "first(inputs | select(.$type)).$type.type" ./config/services/*.toml
fi