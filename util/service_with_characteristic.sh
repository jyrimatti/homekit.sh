#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash jq yq parallel
. ./logging
. ./profiling
set -eu

# Finds the characteristic with the given iid in the accessory with the given aid.
# Returns the characteristic surrounded by its service.

logger_trace 'util/service_with_characteristic.sh'

aid="$1"
iid="$2"

if [ -n "${HOMEKIT_SH_CACHE_ACCESSORIES:-}" ]; then
    jq -ec ".accessories | map(select(.aid == $aid))[0].services | map(.characteristics |= map(select(.iid == $iid)) | select(.characteristics | any)) | .[]" ./store/cache/accessories.json || {
        logger_error "Characteristic $iid from accessory $aid not found!"
        exit 1
    }
else
    service_with_characteristic="$(./util/services_grouped_by_type.sh "$aid" |\
                                   parallel --jobs 0${PROFILING:+1} "./util/generate_service.sh {} | jq -c '.characteristics |= map(select(.iid == $iid)) | select(.characteristics | any)'")"
    if [ -n "${service_with_characteristic:+x}" ]; then
        logger_debug "Found characteristic $aid.$iid"
        echo "$service_with_characteristic";
        exit 0
    fi

    logger_error "Characteristic $iid from accessory $aid not found!"
    exit 1
fi