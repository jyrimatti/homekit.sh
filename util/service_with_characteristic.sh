#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash jq yq
. ./logging
. ./profiling
set -eu

# Finds the characteristic with the given iid in the accessory with the given aid.
# Returns the characteristic surrounded by its service.

logger_trace 'util/service_with_characteristic.sh'

aid=$1
iid=$2

service_with_characteristic=$(./util/services.sh "$aid" |\
                              jq -cs 'group_by(.type) | .[]' |\
                              parallel --jobs 0${PROFILING:+1} "./util/generate_service.sh {} | jq -c '.characteristics |= map(select(.iid == $iid)) | select(.characteristics | any)'")
if [ -n "${service_with_characteristic:+x}" ]; then
    logger_debug "Found characteristic $aid.$iid"
    echo "$service_with_characteristic";
    exit 0
fi

logger_error "Characteristic $iid from accessory $aid not found!"
exit 1