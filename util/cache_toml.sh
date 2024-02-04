#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash coreutils ncurses yq yajsv sqlite
. ./prelude

set -eu

# Caches tomlq JSON output to environment variables, because tomlq is a really slow-to-start python app.

logger_trace 'util/cache_toml.sh'

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

sessionCachePath="$HOMEKIT_SH_RUNTIME_DIR/sessions/${REMOTE_ADDR:-}:${REMOTE_PORT:-}/cache"
target="$sessionCachePath/sqlite"

if [ "${HOMEKIT_SH_CACHE_TOML_DISK:-false}" = "true" ] || [ "${HOMEKIT_SH_CACHE_TOML_SQLITE:-false}" = "true" ]; then
    if [ -f "$target" ]; then
        logger_debug "SQLite cache already exists, thus so must cached TOML files"
    else
        tomls="$(find ./config "$HOMEKIT_SH_ACCESSORIES_DIR" -maxdepth 3 -name '*.toml')"
        echo "$tomls"\
        | ./bin/rust-parallel-"$(uname)" -r '.*' --jobs "${PROFILING:-$(echo "$tomls" | wc -l)}" -s --shell-path dash "test {0} -ot $sessionCachePath/{0} || (mkdir -p \$(dirname $sessionCachePath/{0}) && dash ./util/validate_toml.sh {0} > $sessionCachePath/{0})"
    fi
fi

if [ "${HOMEKIT_SH_CACHE_TOML_FS:-false}" != "false" ]; then
    find ./config/services ./config/characteristics -maxdepth 3 -name '*.toml' | while IFS=$(echo "\n") read -r toml; do
        dir="$HOMEKIT_SH_CACHE_DIR/$toml"
        if [ "$dir" -nt "$toml" ]; then
            logger_debug "Skipping $toml, already cached in $dir"
        else
            logger_info "Caching $toml to directory hierarchy under $dir"
            mkdir -p "$dir"
            touch "$dir"
            dash ./util/validate_toml.sh "$toml" \
                | jq -r 'to_entries | .[] | .key as $name | ("'"$dir/"'" + $name) as $dir | "mkdir -p " + $dir + "; " + ((.value | to_entries | .[] | (if (.value | type) == "array" then (.value | join(",")) else (.value | tostring) end) as $val | "echo -n \"" + $val + "\" > " + $dir + "/" + .key + (if .key == "type" then "; echo -n \"" + $name + "\" > '"$dir/"'" + $val else "" end) ))' \
                | xargs -I{} sh -c {}
        fi
    done
    find "$HOMEKIT_SH_ACCESSORIES_DIR" -maxdepth 3 -name '*.toml' | while IFS=$(echo "\n") read -r toml; do
        dir="$HOMEKIT_SH_CACHE_DIR/$toml"
        if [ "$dir" -nt "$toml" ]; then
            logger_debug "Skipping $toml, already cached in $dir"
        else
            logger_info "Caching $toml to directory hierarchy under $dir"
            mkdir -p "$dir"
            touch "$dir"
            echo -n "$(HOMEKIT_SH_CACHE_TOML_FS=false HOMEKIT_SH_CACHE_TOML_SQLITE=false dash ./util/aid.sh "$toml")" > "$dir/aid"
        fi
    done
fi

if [ "${HOMEKIT_SH_CACHE_TOML_SQLITE:-false}" != "false" ]; then
    if [ -f "$target" ]; then
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

logger_trace 'Finished util/cache_toml.sh'