#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash jq yq ncurses
. ./prefs
. ./log/logging
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

aid="${id%%.*}"
iid="${id##*.}"

service_with_characteristic="$(dash ./util/service_with_characteristic.sh "$aid" "$iid")" || {
    logger_error "Resource $aid.$iid not found!"
    jq -n "{aid: $aid, iid: $iid, status: $resource_does_not_exist }"
    exit 0
}

characs=''
characteristic() {
    if [ -z "$characs" ]; then
        characs="$(echo "$service_with_characteristic" | jq -c '.characteristics[0]')"
    fi
    echo "$characs"
}

if [ "$meta" = '1' ]; then
    logger_debug 'Requested for "meta"'
    ret="$(characteristic | jq "{format, unit, minValue, maxValue, minStep, maxLen} + {aid: $aid, iid: $iid}")"
fi
if [ "$perms" = '1' ]; then
    logger_debug 'Requested for "perms"'
    ret="$(characteristic | jq "{perms} + {aid: $aid, iid: $iid}")"
fi
if [ "$type" = '1' ]; then
    logger_debug 'Requested for "type"'
    ret="$(characteristic| jq "{type} + {aid: $aid, iid: $iid}")"
fi
if [ "$ev" = '1' ]; then
    logger_debug 'Requested for "ev"'
    ret="$(characteristic | jq "{ev} + {aid: $aid, iid: $iid}")"
fi

if [ -z "${ret:-}" ]; then
    ret="{\"aid\": $aid, \"iid\": $iid}"
fi

set +e
value="$(echo "$service_with_characteristic" | dash ./util/value_get.sh "$aid" "$iid")"
responsevalue=$?
set -e
if [ $responsevalue = 158 ]; then
    echo "$ret" | jq ". + { status: $operation_timed_out }"
elif [ $responsevalue = 152 ]; then
    echo "$ret" | jq ". + { status: $unable_to_communicate_with_requested_service }"
elif [ $responsevalue != 0 ]; then
    echo "$ret" | jq ". + { status: $unable_to_communicate_with_requested_service }"
else
    echo "$ret" | jq '. + { value: $value }' --argjson value "$value"
fi
