#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-24.11-small -p dash coreutils ncurses yq yajsv jq
. ./prelude

set -eu

logger_trace 'util/cache_fs_structure.sh'

if [ "${HOMEKIT_SH_CACHE_TOML_FS:-false}" != "false" ]; then
    find ./config/services ./config/characteristics -maxdepth 3 -name '*.toml' \
      | ./bin/rust-parallel-"$(uname)" --jobs "${PROFILING:-$((4*HOMEKIT_SH_PARALLELISM))}" --shell-path dash -s 'lambda() {
        . ./prelude
        toml="$1"
        dir="$HOMEKIT_SH_CACHE_DIR/$toml/fs"
        if [ "$dir" -nt "$toml" ]; then
            logger_debug "Skipping $toml, already cached in $dir"
        else
            logger_info "Caching $toml to directory hierarchy under $dir"
            mkdir -p "$dir"
            touch "$dir"
            dash ./util/validate_toml.sh "$toml" \
                | jq -r '"'"'to_entries | .[] | .key as $name | ("'"'"'"$dir/"'"'"'" + $name) as $dir | "mkdir -p " + $dir + "; " + ((.value | to_entries | .[] | (if (.value | type) == "array" then (.value | join(",")) else (.value | tostring) end) as $val | "echo -n \"" + $val + "\" > " + $dir + "/" + .key + (if .key == "type" then "; echo -n \"" + $name + "\" > '"'"'"$dir/"'"'"'" + $val else "" end) ))'"'"' \
                | xargs -I{} sh -c {}
        fi
    }; lambda'
fi
