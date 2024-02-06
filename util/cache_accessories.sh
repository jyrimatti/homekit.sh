#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash coreutils ncurses yq yajsv
. ./prelude

set -eu

logger_trace 'util/cache_accessories.sh'

if [ "${HOMEKIT_SH_CACHE_TOML_ACCESSORIES:-false}" != "false" ]; then
    find "$HOMEKIT_SH_ACCESSORIES_DIR" -maxdepth 3 -name '*.toml' \
        | ./bin/rust-parallel-"$(uname)" --jobs "${PROFILING:-$((4*HOMEKIT_SH_PARALLELISM))}" --shell-path dash -s 'lambda() {
            . ./prelude
            toml="$1"
            cached="$HOMEKIT_SH_CACHE_DIR/$toml/accessory.json"
            if [ "$cached" -nt "$toml" ]; then
                logger_debug "Skipping $toml, already cached in $cached"
            else
                logger_info "Caching $toml accessory to $cached"
                mkdir -p "$(dirname cached)"
                aid="$(./util/aid.sh "$toml")"
                dash ./util/services_grouped_by_type.sh "$toml" \
                    | tr "\n" "\0" \
                    | xargs -0 -n1  dash ./util/generate_service.sh 1 "$aid" \
                    > "$cached"
            fi
        }; lambda'
fi
