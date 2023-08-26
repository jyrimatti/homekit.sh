#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash jq parallel
. ./logging
. ./profiling
set -eu

logger_trace 'util/generate_service_internal.sh'

index="$1"
service="$(cat)"
typecode=$(echo "$service" | jq -r '.type' | xargs ./util/typecode_service.sh)

service_iid=$(./util/iid_service.sh "$service" "$typecode" "$index")

{
    echo "$service" |\
    jq -cr '.characteristics | keys_unsorted[] as $k | ".[\"\($k)\"] + \(.[$k]|objects // {value:.})"' |\
    parallel --jobs 0${PROFILING:+1} ./util/characteristic.sh |\
    # as Characteristic InstanceID, use its typecode converted to decimal and added to the Service InstanceID
    jq -s 'include "util"; .[] | . += {iid: (.iid // $serviceiid + (.type | to_i(16)))}' --argjson serviceiid "$service_iid" |\
    jq -cs '$service + {type: $typecode, iid: $serviceiid, characteristics: .}' --argjson serviceiid "$service_iid" --arg typecode "$typecode" --argjson service "$service"
} || {
    logger_error 'Could not generate characteristics: check config/characteristic/*.toml'
    exit 1
}
