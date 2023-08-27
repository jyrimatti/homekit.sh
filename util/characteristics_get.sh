#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash jq yq
. ./logging
. ./profiling
set -eu

logger_trace 'util/characteristics_get.sh'

resource_does_not_exist=-70409

meta="$1"
perms="$2"
type="$3"
ev="$4"
id="$5"

aid="$(echo "$id" | cut -d . -f 1)"
iid="$(echo "$id" | cut -d . -f 2)"

ret="{\"aid\": $aid, \"iid\": $iid}"

service_with_characteristic=$(./util/service_with_characteristic.sh "$aid" "$iid") || {
    logger_error "Resource $aid.$iid not found!"
    echo "$ret" | jq ". + { status: $resource_does_not_exist }"
    exit 0
}

characteristic="$(echo "$service_with_characteristic" | jq -c '.characteristics[0]')"

if [ "$meta" = '1' ]; then
    logger_debug 'Requested for "meta"'
    extra=$(echo "$characteristic" | jq -c '{format, unit, minValue, maxValue, minStep, maxLen}')
    ret=$(echo "$ret" | jq '. + $extra' --argjson extra "$extra")
fi
if [ "$perms" = '1' ]; then
    logger_debug 'Requested for "perms"'
    extra=$(echo "$characteristic" | jq -c '{perms}')
    ret=$(echo "$ret" | jq '. + $extra' --argjson extra "$extra")
fi
if [ "$type" = '1' ]; then
    logger_debug 'Requested for "type"'
    extra=$(echo "$characteristic" | jq -c '{type}')
    ret=$(echo "$ret" | jq '. + $extra' --argjson extra "$extra")
fi
if [ "$ev" = '1' ]; then
    logger_debug 'Requested for "ev"'
    extra=$(echo "$characteristic" | jq -c '{ev}')
    ret=$(echo "$ret" | jq '. + $extra' --argjson extra "$extra")
fi

set +e
value=$(echo "$service_with_characteristic" | ./util/value_get.sh)
responsevalue=$?
set -e
if [ $responsevalue = 154 ]; then
    logger_debug '"cmd" not set in characteristic/service properties -> take the constant defined in configuration'
    value=$(echo "$characteristic" | jq '.value')
elif [ "$(echo "$characteristic" | jq '.format')" = 'string' ]; then
    logger_debug 'Value is a string -> wrap it in quotes if not already'
    value=$(echo "$value" | sed 's/^[^"].*[^"]$/"\0"/')
fi
ret=$(echo "$ret" | jq '. + { value: $value }' --argjson value "$value")

echo "$ret" | jq -c 'with_entries(if .value == null then empty else . end)'