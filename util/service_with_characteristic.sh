#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash jq yq ncurses
. ./prelude
set -eu

# Finds the characteristic with the given iid in the accessory with the given aid.
# Returns the characteristic surrounded by its service.

logger_trace 'util/service_with_characteristic.sh'

aid="$1"
iid="$2"

sessionCachePath="$HOMEKIT_SH_RUNTIME_DIR/sessions/${REMOTE_ADDR:-}:${REMOTE_PORT:-}/cache/"
if [ "${HOMEKIT_SH_CACHE_CHARACTERISTICS:-false}" = "true" ] && [ -e "$sessionCachePath/characteristics/$aid.$iid.json" ]; then
    cat "$HOMEKIT_SH_CACHE_DIR/characteristics/$aid.$iid.json"
    logger_debug "Characteristic $aid.$iid retrived from cache"
else
    tomlfile="$(dash ./util/find_accessory.sh "$aid")"
    service_with_characteristic="$(dash ./util/services_grouped_by_type.sh "$tomlfile" \
                                    | ./bin/rust-parallel-"$(uname)" -r '.*' --jobs "${PROFILING:-$HOMEKIT_SH_PARALLELISM}" --shell-path dash -s "dash ./util/generate_service.sh 0 $aid '{0}' | jq -c '.characteristics |= map(select(.iid == $iid)) | select(.characteristics | any)'")"
    if [ -n "${service_with_characteristic:+x}" ]; then
        logger_debug "Found characteristic $aid.$iid"
        echo "$service_with_characteristic"

        if [ "${HOMEKIT_SH_CACHE_CHARACTERISTICS:-false}" = "true" ]; then
            mkdir -p "$sessionCachePath"/characteristics
            logger_debug "Caching characteristic $aid.$iid to $sessionCachePath/characteristics/$aid.$iid.json"
            echo "$service_with_characteristic" > "$sessionCachePath/characteristics/$aid.$iid.json"
        fi
        exit 0
    fi

    exit 1
fi