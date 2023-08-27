#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash coreutils jq
. ./logging
. ./profiling
set -eu

logger_trace 'util/generate_service_internal.sh'

index="$1"
service="$(cat)"

typecode=$(echo "$service" | jq -r '.type' | xargs ./util/typecode_service.sh)
service_iid=$(./util/iid_service.sh "$service" "$typecode" "$index")

if [ -n "${BETA:-}" ]; then
    query='first(select(.[\"\($k)\"]))'
else
    query='.'
fi

{
    echo "$service" |\
    jq -cr ".characteristics | keys_unsorted[] as \$k | \"$query"'[\"\($k)\"] + \(.[$k]|objects // {value:.})" | @sh' |\
    xargs ./util/characteristic.sh |\
    # as Characteristic InstanceID, use its typecode converted to decimal and added to the Service InstanceID
    jq -c "include \"util\"; . + {iid: (.iid // $service_iid + (.type | to_i(16)))}" |\
    jq -cs "\$service + {type: \"$typecode\", iid: $service_iid, characteristics: .}" --argjson service "$service"
} || {
    logger_error 'Could not generate characteristics: check config/characteristic/*.toml'
    exit 1
}
