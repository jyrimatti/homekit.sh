#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-24.11-small -p nix dash yq jq ncurses
. ./prelude

set -eu

logger_trace 'util/typecode_service.sh'

type="$1"

if [ "${HOMEKIT_SH_CACHE_TOML_FS:-false}" = "true" ]; then
    logger_debug 'Using FS cached services'
    for toml in ./config/services/*.toml; do
        file="$HOMEKIT_SH_CACHE_DIR/$toml/fs/$type/type"
        if [ -f "$file" ]; then
            IFS= read -r line < "$file" || true
            echo -n "$line"
            break
        fi
    done
else
    dash ./util/tomlq-cached.sh -ren "first(inputs | select(.$type)).$type.type" ./config/services/*.toml
fi