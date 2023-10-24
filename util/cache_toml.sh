#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p dash coreutils ncurses yq yajsv sqlite
. ./prefs
. ./log/logging
. ./profiling

set -eu

# Caches tomlq JSON output to environment variables, because tomlq is a really slow-to-start python app.

logger_debug 'util/cache_toml.sh'

if [ "${HOMEKIT_SH_CACHE_TOML_ENV:-false}" = "true" ]; then
    tmpfile="$(mktemp "$HOMEKIT_SH_RUNTIME_DIR/homekit.sh_cache_toml.XXXXXX")"
    find ./config "$HOMEKIT_SH_ACCESSORIES_DIR" -name '*.toml' |
        ./bin/rust-parallel-"$(uname)" -r '.*' --jobs "${PROFILING:-32}" "content=\"\$(dash ./util/validate_toml.sh {0})\" && echo \"export HOMEKIT_SH_\$(dash ./util/cache_mkkey.sh {0})='\$content' && logger_debug 'Cached {0} to HOMEKIT_SH_\$(dash ./util/cache_mkkey.sh \"{0}\")'\"" > "$tmpfile"

    while IFS=$(echo "\n") read -r line; do
        eval "$line"
    done < "$tmpfile"
    rm "$tmpfile"
fi

if [ "${HOMEKIT_SH_CACHE_TOML_DISK:-false}" = "true" ]; then
    find config "$HOMEKIT_SH_ACCESSORIES_DIR" -name '*.toml' |
        ./bin/rust-parallel-"$(uname)" -r '.*' --jobs "${PROFILING:-32}" dash -c "test {0} -ot $HOMEKIT_SH_CACHE_DIR/{0} || (mkdir -p \$(dirname $HOMEKIT_SH_CACHE_DIR/{0}) && dash ./util/validate_toml.sh {0} > $HOMEKIT_SH_CACHE_DIR/{0})"
fi

if [ "${HOMEKIT_SH_CACHE_TOML_SQLITE:-false}" != "false" ]; then
    target="$(mktemp "$HOMEKIT_SH_RUNTIME_DIR/homekit.sh_cache_toml.XXXXXX")"
    logger_debug "Caching services, characteristics, and accessories to SQLite database: $target"

    servicescsv="$(mktemp "$HOMEKIT_SH_RUNTIME_DIR/homekit.sh_cache_toml.XXXXXX")"
    characteristicscsv="$(mktemp "$HOMEKIT_SH_RUNTIME_DIR/homekit.sh_cache_toml.XXXXXX")"
    accessoriescsv="$(mktemp "$HOMEKIT_SH_RUNTIME_DIR/homekit.sh_cache_toml.XXXXXX")"

    {
        echo "dash ./util/tomlq-cached.sh -r 'to_entries | map([.key, .value.type]) | .[] | @csv' ./config/services/*.toml > '$servicescsv'"
        echo "dash ./util/tomlq-cached.sh -r 'to_entries | map([.key, .value.type, (.value.perms // [] | join(\",\")), .value.format, .value.minValue, .value.maxValue, .value.minStep, .value.maxLen, .value.unit, (.value[\"valid-values\"] // [] | join(\",\"))]) | .[] | @csv' ./config/characteristics/*.toml > '$characteristicscsv'"
        echo "find '$HOMEKIT_SH_ACCESSORIES_DIR' -name '*.toml' | ./bin/rust-parallel-$(uname) --jobs ${PROFILING:-32} -r '.*' -s --shell-path dash 'echo \$(dash ./util/aid.sh {0}),\"{0}\"' > '$accessoriescsv'"
    } | ./bin/rust-parallel-"$(uname)" --jobs "${PROFILING:-32}" -s --shell-path dash

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

    logger_debug "Caching to SQLite done"
fi