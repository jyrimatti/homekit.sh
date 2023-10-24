#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash yq jq ncurses
. ./prefs
. ./log/logging
. ./profiling

set -eu

# use Accessory Instance ID from toml file if provided, or hash the file path

logger_trace 'util/aid.sh'

tomlfile="$1"

if [ -e "${HOMEKIT_SH_CACHE_TOML_SQLITE:-}" ]; then
    logger_debug 'Using SQLite cached accessories'
    sqlite3 "$HOMEKIT_SH_CACHE_TOML_SQLITE" "select aid from accessories where file='$tomlfile'"
else
    dash ./util/tomlq-cached.sh -re '.aid // empty' "$tomlfile" || { echo "$tomlfile" | dash ./util/hash.sh; }
fi