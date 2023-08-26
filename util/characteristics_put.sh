#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash jq
. ./logging
. ./profiling
set -eu

logger_trace 'util/characteristics_put.sh'

resource_does_not_exist=-70409
unable_to_communicate_with_requested_service=-70402
cannot_write_to_read_only_characteristic=-70404
accessory_received_an_invalid_value_in_a_write_request=-70410
notification_is_not_supported_for_characteristic=-70406
operation_timed_out=-70408

aid="$1"
iid="$2"
value="$3"
ev="$4"
authData="$5"
remote="$6"
response="$7"

session_store="./store/sessions/$REMOTE_ADDR:$REMOTE_PORT"

ret=$(jq -n "{ aid: $aid, iid: $iid }")
service_with_characteristic=$(./util/service_with_characteristic.sh "$aid" "$iid") || {
    logger_error "Resource $aid.$iid not found!"
    echo "$ret" | jq ". + {status: $resource_does_not_exist}"
    exit 0
}

if [ "$value" != 'null' ]; then
    logger_debug 'Value was provided -> trying to write it'
    set +e
    echo "$service_with_characteristic" | ./util/value_set.sh "$value"
    responsevalue=$?
    set -e
    if [ $responsevalue = 154 ]; then
        logger_error "Got responsecode $responsevalue while writing value"
        ret=$(echo "$ret" | jq ". + { status: $cannot_write_to_read_only_characteristic }")
    elif [ $responsevalue = 158 ]; then
        logger_error "Got responsecode $responsevalue while writing value"
        ret=$(echo "$ret" | jq ". + { status: $operation_timed_out }")
    elif [ $responsevalue != 0 ]; then
        logger_error "Got responsecode $responsevalue while writing value"
        ret=$(echo "$ret" | jq ". + { status: $accessory_received_an_invalid_value_in_a_write_request }")
    elif [ "$response" = 'true' ]; then
        logger_debug 'Requested for "value"'
        ret=$(echo "$ret" | jq '. + { value: $value }' --argjson value "$value")
    fi
fi

if [ "$ev" = 'true' ]; then
    logger_info 'Subscribing to events'
    mkdir -p "$session_store/subscriptions"

    logger_debug "Creating event for $aid $iid"
    value=$(echo "$service_with_characteristic" | ./util/value_get.sh)
    tmpfile=$(mktemp /tmp/homekit.sh_characteristics_put.XXXXXX)
    ./util/event_create.sh "$aid" "$iid" "$value" > "$tmpfile"
    subscription="$session_store/subscriptions/${aid}.${iid}"
    mv "$tmpfile" "$session_store/events/${aid}.${iid}.json"
    echo "$value" > "$subscription"
    logger_debug "Subscribed $subscription"
elif [ "$ev" = 'false' ]; then
    logger_info 'Unsubscribing from events'
    subscription="$session_store/subscriptions/${aid}.${iid}"
    rm -f "$subscription"
    logger_debug "Unsubscribed $subscription"
fi

echo "$ret" | jq -c 'with_entries(if .value == null then empty else . end)'