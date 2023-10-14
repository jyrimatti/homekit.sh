#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash jq ncurses
. ./prefs
. ./logging
. ./profiling
set -eu

logger_trace 'util/characteristics_put.sh'

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

aid="$1"
iid="$2"
value="$3"
ev="$4"
authData="$5"
remote="$6"
response="$7"

session_store="$HOMEKIT_SH_RUNTIME_DIR/sessions/$REMOTE_ADDR:$REMOTE_PORT"

service_with_characteristic="$(dash ./util/service_with_characteristic.sh "$aid" "$iid")" || {
    logger_error "Resource $aid.$iid not found!"
    echo "{\"aid\": $aid, \"iid\": $iid, \"status\": $resource_does_not_exist}"
    exit 0
}

toString() {
    servicename="$(echo "$service_with_characteristic" | jq -r '.type' | xargs dash ./util/type_to_string.sh)"
    characteristicname="$(echo "$service_with_characteristic" | jq -r '.characteristics[0].type' | xargs dash ./util/type_to_string.sh)"
    echo "$aid.$iid ($servicename.$characteristicname)"
}

ret="{\"aid\": $aid, \"iid\": $iid, \"status\": 0}"
if [ "$value" != 'null' ]; then
    logger_debug 'Value was provided -> trying to write it'
    set +e
    echo "$service_with_characteristic" | dash ./util/value_set.sh "$aid" "$iid" "$value"
    responsevalue=$?
    set -e
    if [ $responsevalue = 154 ]; then
        logger_error "Got responsecode $responsevalue while writing value for $(toString)"
        ret="{\"aid\": $aid, \"iid\": $iid, \"status\": $cannot_write_to_read_only_characteristic}"
    elif [ $responsevalue = 158 ]; then
        logger_error "Got timeout while writing value for $(toString)"
        ret="{\"aid\": $aid, \"iid\": $iid, \"status\": $operation_timed_out}"
    elif [ $responsevalue != 0 ]; then
        logger_error "Got errorcode $responsevalue while writing value for $(toString)"
        ret="{\"aid\": $aid, \"iid\": $iid, \"status\": $accessory_received_an_invalid_value_in_a_write_request}"
    elif [ "$response" = 'true' ]; then
        logger_debug 'Requested for "value"'
        ret="{\"aid\": $aid, \"iid\": $iid, \"value\": $value}"
    fi
fi

if [ "$ev" = 'true' ]; then
    echo "$service_with_characteristic" |
    jq -r '[.type, .characteristics[0].type, .polling // .characteristics[0].polling // " ", .characteristics[0].cmd // .cmd // " "] | @tsv' |
    while IFS=$(echo "\t") read -r servicetype characteristictype polling cmd
    do
        logger_info "Subscribing to events for $aid.$iid ($servicetype.$characteristictype)"
        
        if [ "$polling" = ' ' ]; then
            logger_warn "No 'polling' defined for $aid.$iid. Will not be able to automatically produce events for $(toString)"
            ret="{\"aid\": $aid, \"iid\": $iid, \"status\": $notification_is_not_supported_for_characteristic}"
        elif [ "$cmd" = ' ' ]; then
            logger_warn "No 'cmd' defined for $aid.$iid. Will not be able to automatically produce events for $(toString)"
            ret="{\"aid\": $aid, \"iid\": $iid, \"status\": $notification_is_not_supported_for_characteristic}"
        else
            test -e "$session_store/subscriptions" || mkdir -p "$session_store/subscriptions"
            subscription="$session_store/subscriptions/${aid}.${iid}"
            test -e "$session_store/events" || mkdir -p "$session_store/events"
            echo '' > "$subscription"
            logger_debug "Subscribed $subscription"
        fi
        echo "$ret"
    done
elif [ "$ev" = 'false' ]; then
    logger_info "Unsubscribing from events for $(toString)"
    subscription="$session_store/subscriptions/${aid}.${iid}"
    rm -f "$subscription"
    logger_debug "Unsubscribed $subscription"

    echo "$ret"
else
    echo "$ret"
fi
