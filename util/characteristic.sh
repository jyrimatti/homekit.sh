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
                cd "$dir"
                IFS=
                test -e ./minValue     && { read -r line < ./minValue     || true; echo -n "minValue:$line,"; }
                test -e ./maxValue     && { read -r line < ./maxValue     || true; echo -n "maxValue:$line,"; }
                test -e ./minStep      && { read -r line < ./minStep      || true; echo -n "minStep:$line,"; }
                test -e ./valid-values && { read -r line < ./valid-values || true; echo -n "\"valid-values\":[$line],"; }
                test -e ./unit         && { read -r line < ./unit         || true; echo -n "unit:\"$line\","; }
                test -e ./maxLen       && { read -r line < ./maxLen       || true; echo -n "maxLen:$line,"; }
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
