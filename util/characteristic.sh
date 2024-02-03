#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash yq jq ncurses
. ./prelude

set -eu

logger_trace 'util/characteristic.sh'

if [ "${HOMEKIT_SH_CACHE_TOML_FS:-false}" = "true" ]; then
    logger_debug 'Using FS cached characteristics'
    name="$1"
    data="$2"
    for toml in ./config/characteristics/*.toml; do
        dir="$HOMEKIT_SH_CACHE_DIR/$(dash ./util/hash.sh "$toml")/$name"
        if [ -e "$dir" ]; then
            jsondata() {
                # sed seems faster than cat...
                cd "$dir"
                test -e ./minValue     && sed 's/.*/minValue:&,/' ./minValue
                test -e ./maxValue     && sed 's/.*/maxValue:&,/' ./maxValue
                test -e ./minStep      && sed 's/.*/minStep:&,/' ./minStep
                test -e ./valid-values && sed 's/.*/"valid-values":[&],/' ./valid-values
                test -e ./unit         && sed 's/.*/unit:"&",/' ./unit
                test -e ./maxLen       && sed 's/.*/maxLen:&,/' ./maxLen
            }
            jq -nc "{$(jsondata) typeName:\"$name\",
                                 type:\$type,
                                 perms: \$perms | split(\",\"),
                                 format: \$format} + \$data" \
                                --rawfile type "$dir/type" \
                                --rawfile perms "$dir/perms" \
                                --rawfile format "$dir/format" \
                                --argjson data "$data"
            break
        fi
    done
else
    IFS=,
    dash ./util/tomlq-cached.sh -ce "$*" ./config/characteristics/*.toml
fi
