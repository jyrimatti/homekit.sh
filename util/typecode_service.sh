#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash yq jq ncurses sqlite
. ./prefs
. ./log/logging
. ./profiling
set -eu

logger_trace 'util/typecode_service.sh'

type="$1"

if [ -e "${HOMEKIT_SH_CACHE_TOML_SQLITE:-}" ]; then
    logger_debug 'Using SQLite cached services'
    sqlite3 "$HOMEKIT_SH_CACHE_TOML_SQLITE" "select typeCode from services where typeName='$type'"
else
    dash ./util/tomlq-cached.sh -ren "first(inputs | select(.$type)).$type.type" ./config/services/*.toml
fi