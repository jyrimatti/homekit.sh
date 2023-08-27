#! /usr/bin/env dash
. ./logging
. ./profiling

set -eu

# Caches tomlq JSON output to environment variables, because tomlq is a really slow-to-start python app.

logger_debug 'util/cache_toml.sh'

if [ -n "${HOMEKIT_SH_CACHE_TOML:-}" ]; then
    tmpfile=$(mktemp /tmp/homekit.sh_cache_toml.XXXXXX)
    find ./config ./accessories -name '*.toml' |\
        parallel --jobs 0${PROFILING:+1} "content=\"\$(./util/validate_toml.sh {})\" && echo \"export HOMEKIT_SH_\$(./util/cache_mkkey.sh {})='\$content' && logger_debug 'Cached {} to HOMEKIT_SH_\$(./util/cache_mkkey.sh "{}")'\"" > "$tmpfile"

    while IFS=$(echo "\n") read -r line; do
        eval "$line"
    done < "$tmpfile"
fi

if [ -n "${HOMEKIT_SH_CACHE_TOML_DISK:-}" ]; then
    find ./config ./accessories -name '*.toml' |\
        parallel -u --jobs 0${PROFILING:+1} "./util/validate_toml.sh {} > /tmp/HOMEKIT_SH_\$(./util/cache_mkkey.sh {})"
fi
