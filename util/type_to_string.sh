#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash yq jq ncurses
. ./prelude

set -eu

logger_trace 'util/type_to_string.sh'

type="$1"

if [ "${HOMEKIT_SH_CACHE_TOML_FS:-false}" = "true" ]; then
    logger_debug 'Using FS cached services/characteristics'
    for toml in ./config/services/*.toml ./config/characteristics/*.toml; do
        file="$HOMEKIT_SH_CACHE_DIR/$toml/fs/$type"
        if [ -f "$file" ]; then
            IFS= read -r line < "$file" || true
            echo -n "$line"
            break
        fi
    done
else
    dash ./util/tomlq-cached.sh -rn "first(inputs | select(.[] | .type == \"$type\") | keys[0])" ./config/services/*.toml ./config/characteristics/*.toml
fi
