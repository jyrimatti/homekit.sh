#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p dash coreutils ncurses yq yajsv
. ./logging
. ./profiling

set -eu

# Caches tomlq JSON output to environment variables, because tomlq is a really slow-to-start python app.

logger_debug 'util/cache_toml.sh'

if [ "${HOMEKIT_SH_CACHE_TOML_ENV:-false}" = "true" ]; then
    tmpfile="$(mktemp /tmp/homekit.sh_cache_toml.XXXXXX)"
    find ./config ./accessories -name '*.toml' |
        ./bin/rust-parallel-"$(uname)" -r '.*' --jobs "${PROFILING:-32}" "content=\"\$(dash ./util/validate_toml.sh {0})\" && echo \"export HOMEKIT_SH_\$(dash ./util/cache_mkkey.sh {0})='\$content' && logger_debug 'Cached {0} to HOMEKIT_SH_\$(dash ./util/cache_mkkey.sh \"{0}\")'\"" > "$tmpfile"

    while IFS=$(echo "\n") read -r line; do
        eval "$line"
    done < "$tmpfile"
    rm "$tmpfile"
fi

if [ "${HOMEKIT_SH_CACHE_TOML_DISK:-false}" = "true" ]; then
    find config accessories -name '*.toml' |
        ./bin/rust-parallel-"$(uname)" -r '.*' --jobs "${PROFILING:-32}" dash -c "test {0} -ot $HOMEKIT_SH_CACHE_DIR/{0} || (mkdir -p \$(dirname $HOMEKIT_SH_CACHE_DIR/{0}) && dash ./util/validate_toml.sh {0} > $HOMEKIT_SH_CACHE_DIR/{0})"
fi
