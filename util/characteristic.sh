#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash yq jq ncurses
. ./prefs
. ./log/logging
. ./profiling

set -eu

logger_trace 'util/characteristic.sh'

if [ "${HOMEKIT_SH_CACHE_TOML_FS:-false}" = "true" ]; then
    logger_debug 'Using FS cached characteristics'
    name="$1"
    data="$2"
    for toml in ./config/characteristics/*.toml; do
        dir="$HOMEKIT_SH_CACHE_DIR/$(dash ./util/hash.sh "$toml")/$name"
        if [ -e "$dir" ]; then
            echo "$data" | jq "{typeName:\"$name\",
                                type:\"$(cat "$dir/type" 2>/dev/null)\",
                                perms:(\"$(cat "$dir/perms" 2>/dev/null)\" | split(\",\")),
                                format:\"$(cat "$dir/format" 2>/dev/null)\",
                                minValue:$(cat "$dir/minValue" 2>/dev/null || echo -n 'null'),
                                maxValue:$(cat "$dir/maxValue" 2>/dev/null || echo -n 'null'),
                                minStep:$(cat "$dir/minStep" 2>/dev/null || echo -n 'null'),
                                \"valid-values\":(\"$(cat "$dir/valid-values" 2>/dev/null)\" | split(\",\") | map(tonumber)),
                                unit:\"$(cat "$dir/unit" 2>/dev/null)\",
                                maxLen:$(cat "$dir/maxLen" 2>/dev/null || echo -n 'null')} + . | with_entries(select(.value |.!=null and . != \"\" and (type != \"array\" or length>0)))"
            exit 0
        fi
    done
else
    IFS=,
    dash ./util/tomlq-cached.sh -ce "$*" ./config/characteristics/*.toml
fi
