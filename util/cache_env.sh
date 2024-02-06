#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash coreutils ncurses yq yajsv
. ./prelude

set -eu

logger_trace 'util/cache_env.sh'

if [ "${HOMEKIT_SH_CACHE_TOML_ENV:-false}" = "true" ]; then
    tmpfile="$(mktemp "$HOMEKIT_SH_RUNTIME_DIR/homekit.sh_cache_toml.XXXXXX")"
    tomls="$(find ./config "$HOMEKIT_SH_ACCESSORIES_DIR" -maxdepth 3 -name '*.toml')"
    echo "$tomls"\
     | ./bin/rust-parallel-"$(uname)" -r '.*' --jobs "${PROFILING:-$(echo "$tomls" | wc -l)}" "content=\"\$(dash ./util/validate_toml.sh {0})\" && echo \"export HOMEKIT_SH_\$(dash ./util/cache_mkkey.sh {0})='\$content' && logger_debug 'Cached {0} to HOMEKIT_SH_\$(dash ./util/cache_mkkey.sh \"{0}\")'\""\
     > "$tmpfile"

    while IFS=$(echo "\n") read -r line; do
        eval "$line"
    done < "$tmpfile"
    rm "$tmpfile"
fi
