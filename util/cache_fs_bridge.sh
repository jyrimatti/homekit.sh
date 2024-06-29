#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash coreutils ncurses yq yajsv
. ./prelude

set -eu

logger_trace 'util/cache_fs_bridge.sh'

if [ "${HOMEKIT_SH_CACHE_TOML_FS:-false}" != "false" ]; then
    find "$HOMEKIT_SH_ACCESSORIES_DIR" -maxdepth 3 -name '*.toml' \
      | ./bin/rust-parallel-"$(uname)" --jobs "${PROFILING:-$((4*HOMEKIT_SH_PARALLELISM))}" --shell-path dash -s 'lambda() {
        . ./prelude
        toml="$1"
        cached="$HOMEKIT_SH_CACHE_DIR/$toml/bridge"
        if [ "$cached" -nt "$toml" ]; then
            logger_debug "Skipping $toml, already cached in $cached"
        else
            logger_info "Caching $toml bridge to $cached"
            mkdir -p "$(dirname "$cached")"
            dash ./util/tomlq-cached.sh -r ".bridge // empty" "$toml" > "$cached"
        fi
    }; lambda'
fi
