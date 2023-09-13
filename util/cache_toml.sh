#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p dash coreutils ncurses parallel yq yajsv
. ./logging
. ./profiling

set -eu

# Caches tomlq JSON output to environment variables, because tomlq is a really slow-to-start python app.

logger_debug 'util/cache_toml.sh'

if [ -n "${HOMEKIT_SH_CACHE_TOML_ENV:-}" ]; then
    tmpfile="$(mktemp /tmp/homekit.sh_cache_toml.XXXXXX)"
    find ./config ./accessories -name '*.toml' |\
        parallel --jobs 0${PROFILING:+1} "content=\"\$(dash ./util/validate_toml.sh {})\" && echo \"export HOMEKIT_SH_\$(dash ./util/cache_mkkey.sh {})='\$content' && logger_debug 'Cached {} to HOMEKIT_SH_\$(dash ./util/cache_mkkey.sh "{}")'\"" > "$tmpfile"

    while IFS=$(echo "\n") read -r line; do
        eval "$line"
    done < "$tmpfile"
    rm "$tmpfile"
fi

if [ -n "${HOMEKIT_SH_CACHE_TOML_DISK:-}" ]; then
    find config accessories -name '*.toml' |\
        parallel -u --jobs 0${PROFILING:+1} "test {} -nt $CACHE_DIR/{} || { mkdir -p \$(dirname $CACHE_DIR/{}) && dash ./util/validate_toml.sh {} > $CACHE_DIR/{}; }"
fi
