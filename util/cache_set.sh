#! /usr/bin/env dash
. ./logging
. ./profiling

set -eu

# Caches tomlq JSON output to environment variables, because tomlq is a really slow-to-start python app.

logger_debug 'util/cache_set.sh'

tmpfile=$(mktemp /tmp/homekit.sh_cache_set.XXXXXX)
find ./config ./accessories -name '*.toml' |\
    parallel --jobs 0${PROFILING:+1} "content=\"\$(./util/validate_toml.sh {})\" && echo \"export HOMEKIT_SH_\$(./util/cache_mkkey.sh {})='\$content' && logger_debug 'Cached {} to HOMEKIT_SH_\$(./util/cache_mkkey.sh "{}")'\"" > "$tmpfile"

while IFS=$(echo "\n") read -r line; do
    eval "$line"
done < "$tmpfile"
