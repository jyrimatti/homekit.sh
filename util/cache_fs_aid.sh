#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-24.11-small -p dash coreutils ncurses yq yajsv
. ./prelude

set -eu

logger_trace 'util/cache_fs_aid.sh'

if [ "${HOMEKIT_SH_CACHE_TOML_FS:-false}" != "false" ]; then
    find "$HOMEKIT_SH_ACCESSORIES_DIR" -maxdepth 3 -name '*.toml' \
      | ./bin/rust-parallel-"$(uname)" --jobs "${PROFILING:-$((4*HOMEKIT_SH_PARALLELISM))}" --shell-path dash -s 'lambda() {
        . ./prelude
        toml="$1"
        cached="$HOMEKIT_SH_CACHE_DIR/$toml/aid"
        if [ "$cached" -nt "$toml" ]; then
            logger_debug "Skipping $toml, already cached in $cached"
        else
            logger_info "Caching $toml aid to $cached"
            mkdir -p "$(dirname "$cached")"
            echo -n "$(HOMEKIT_SH_CACHE_TOML_FS=false dash ./util/aid.sh "$toml")" > "$cached"
        fi
    }; lambda'
fi
