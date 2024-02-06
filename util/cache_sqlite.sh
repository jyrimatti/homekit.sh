#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash coreutils ncurses yq yajsv sqlite
. ./prelude

set -eu

logger_trace 'util/cache_sqlite.sh'

if [ "${HOMEKIT_SH_CACHE_TOML_SQLITE:-false}" != "false" ]; then
    target="$HOMEKIT_SH_CACHE_DIR/sqlite"
    if (find ./config "$HOMEKIT_SH_ACCESSORIES_DIR" -maxdepth 3 -name '*.toml' | while IFS=$(echo "\n") read -r toml; do
        if [ "$target" -ot "$toml" ]; then
            exit 1 # invalidated
        fi
    done); then
        logger_debug "Using existing SQLite cache"
    else
        logger_debug "Caching services, characteristics, and accessories to SQLite database: $target"

        servicescsv="$(mktemp "$HOMEKIT_SH_RUNTIME_DIR/homekit.sh_cache_toml.XXXXXX")"
        characteristicscsv="$(mktemp "$HOMEKIT_SH_RUNTIME_DIR/homekit.sh_cache_toml.XXXXXX")"
        accessoriescsv="$(mktemp "$HOMEKIT_SH_RUNTIME_DIR/homekit.sh_cache_toml.XXXXXX")"

        tomlCount="$(find ./config "$HOMEKIT_SH_ACCESSORIES_DIR" -name '*.toml' | wc -l)"
        {
            echo "dash ./util/tomlq-cached.sh -r 'to_entries | map([.key, .value.type]) | .[] | @csv' ./config/services/*.toml > '$servicescsv'"
            echo "dash ./util/tomlq-cached.sh -r 'to_entries | map([.key, .value.type, (.value.perms // [] | join(\",\")), .value.format, .value.minValue, .value.maxValue, .value.minStep, .value.maxLen, .value.unit, (.value[\"valid-values\"] // [] | join(\",\"))]) | .[] | @csv' ./config/characteristics/*.toml > '$characteristicscsv'"
            echo "find '$HOMEKIT_SH_ACCESSORIES_DIR' -maxdepth 3 -name '*.toml' | ./bin/rust-parallel-$(uname) --jobs ${PROFILING:-$tomlCount} -r '.*' -s --shell-path dash 'echo \$(dash ./util/aid.sh {0}),\"{0}\"' > '$accessoriescsv'"
        } | ./bin/rust-parallel-"$(uname)" --jobs "${PROFILING:-3}" -s --shell-path dash

        HOMEKIT_SH_CACHE_TOML_SQLITE="$target"
        export HOMEKIT_SH_CACHE_TOML_SQLITE

        sqlite3 "$target" << EOF
create table accessories(aid INTEGER, file TEXT);
create index accessories_aid on accessories(aid);
create index accessories_file on accessories(file);
create table services(typeName TEXT, typeCode TEXT);
create index services_typeName on services(typeName);
create index services_typeCode on services(typeCode);
create table characteristics(typeName TEXT, typeCode TEXT, perms TEXT, format TEXT, minValue TEXT, maxValue TEXT, minStep TEXT, maxLen INTEGER, unit TEXT, validvalues TEXT);
create index characteristics_typeName on characteristics(typeName);
create index characteristics_typeCode on characteristics(typeCode);
.mode csv
.import "$servicescsv" services
.import "$characteristicscsv" characteristics
.import "$accessoriescsv" accessories
EOF
        rm "$servicescsv"
        rm "$characteristicscsv"
        rm "$accessoriescsv"

        logger_debug "Caching to SQLite done"
    fi
fi
