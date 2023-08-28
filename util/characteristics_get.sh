#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash jq yq ncurses
. ./logging
. ./profiling
set -eu

logger_trace 'util/characteristics_get.sh'

request_denied_due_to_insufficient_privileges=-70401
unable_to_communicate_with_requested_service=-70402
resource_is_busy_try_again_=-70403
cannot_write_to_read_only_characteristic=-70404
cannot_read_from_a_write_only_characteristic=-70405
notification_is_not_supported_for_characteristic=-70406
out_of_resources_to_process_request=-70407
operation_timed_out=-70408
resource_does_not_exist=-70409
accessory_received_an_invalid_value_in_a_write_request=-70410
insufficient_authorization=-70411

meta="$1"
perms="$2"
type="$3"
ev="$4"
id="$5"

aid="$(echo "$id" | cut -d . -f 1)"
iid="$(echo "$id" | cut -d . -f 2)"

ret="{\"aid\": $aid, \"iid\": $iid}"

service_with_characteristic="$(dash ./util/service_with_characteristic.sh "$aid" "$iid")" || {
    logger_error "Resource $aid.$iid not found!"
    echo "$ret" | jq ". + { status: $resource_does_not_exist }"
    exit 0
}

servicename="$(echo "$service_with_characteristic" | jq -r '.type' | xargs dash ./util/type_to_string.sh)"
characteristicname="$(echo "$service_with_characteristic" | jq -r '.characteristics[0].type' | xargs dash ./util/type_to_string.sh)"
characteristic="$(echo "$service_with_characteristic" | jq -c '.characteristics[0]')"

if [ "$meta" = '1' ]; then
    logger_debug 'Requested for "meta"'
    ret="$(echo "$characteristic" | jq '{format, unit, minValue, maxValue, minStep, maxLen} + $ret' --argjson ret "$ret")"
fi
if [ "$perms" = '1' ]; then
    logger_debug 'Requested for "perms"'
    ret="$(echo "$characteristic" | jq '{perms} + $ret' --argjson ret "$ret")"
fi
if [ "$type" = '1' ]; then
    logger_debug 'Requested for "type"'
    ret="$(echo "$characteristic" | jq '{type} + $ret' --argjson ret "$ret")"
fi
if [ "$ev" = '1' ]; then
    logger_debug 'Requested for "ev"'
    ret="$(echo "$characteristic" | jq '{ev} + $ret' --argjson ret "$ret")"
fi

set +e
value="$(echo "$service_with_characteristic" | dash ./util/value_get.sh)"
responsevalue=$?
set -e
if [ $responsevalue = 154 ]; then
    logger_debug "\"cmd\" not set in characteristic/service properties for $characteristicname@$servicename -> take the constant defined in configuration"
    value="$(echo "$characteristic" | jq '.value')"
elif [ $responsevalue = 158 ]; then
    ret="$(echo "$ret" | jq ". + { status: $operation_timed_out }")"
elif [ $responsevalue = 152 ]; then
    ret="$(echo "$ret" | jq ". + { status: $unable_to_communicate_with_requested_service }")"
elif [ $responsevalue != 0 ]; then
    ret="$(echo "$ret" | jq ". + { status: $unable_to_communicate_with_requested_service }")"
else
    if [ "$(echo "$characteristic" | jq '.format')" = 'string' ]; then
        logger_debug 'Value is a string -> wrap it in quotes if not already'
        value="$(echo "$value" | sed 's/^[^"].*[^"]$/"\0"/')"
    fi
    ret="$(echo "$ret" | jq '. + { value: $value }' --argjson value "$value")"
fi

echo "$ret" | jq -c 'with_entries(if .value == null then empty else . end)'