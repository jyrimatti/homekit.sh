#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash yq jq ncurses
. ./prelude

set -eu

# use Accessory Instance ID from toml file if provided, or hash the file path

logger_trace 'util/aid.sh'

tomlfile="$1"

if [ "${HOMEKIT_SH_CACHE_TOML_FS:-false}" = "true" ]; then
    logger_debug 'Using FS cached accessories'
    sed '' "$HOMEKIT_SH_CACHE_DIR/$(dash ./util/hash.sh "$tomlfile")/aid"
elif [ -e "${HOMEKIT_SH_CACHE_TOML_SQLITE:-}" ]; then
    logger_debug 'Using SQLite cached accessories'
    sqlite3 -readonly "$HOMEKIT_SH_CACHE_TOML_SQLITE" "select aid from accessories where file='$tomlfile'"
else
    dash ./util/tomlq-cached.sh -re '.aid // empty' "$tomlfile" || { echo "$tomlfile" | dash ./util/hash.sh; }
fi