#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash coreutils ncurses yq yajsv
. ./prelude

set -eu

logger_trace 'util/cache_disk.sh'

if [ "${HOMEKIT_SH_CACHE_TOML_DISK:-false}" = "true" ]; then
    find ./config "$HOMEKIT_SH_ACCESSORIES_DIR" -maxdepth 3 -name '*.toml' | while IFS=$(echo "\n") read -r toml; do
        cached="$HOMEKIT_SH_CACHE_DIR/toml2json/$toml"
        if [ "$cached" -nt "$toml" ]; then
            logger_debug "Skipping $toml, already cached in $cached"
        else
            logger_info "Caching $toml to disk in $cached"
            mkdir -p "$(dirname "$cached")"
            dash ./util/validate_toml.sh "$toml" > "$cached"
        fi
    done
fi
