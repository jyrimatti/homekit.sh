#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash jq
. ./logging
. ./profiling
set -eu

logger_trace 'util/poll.sh'

session="$1"
subscription="$2"

subscription_path="./store/sessions/$session/subscriptions/$subscription"
if test -f "$subscription_path"; then
    logger_debug "Polling $subscription_path"

    age=$(($(date +%s) - $(date +%s -r "$subscription_path")))
    previous_value=$(cat "$subscription_path")

    logger_debug "Got age $age"

    aid=$(echo "$subscription" | cut -d . -f 1)
    iid=$(echo "$subscription" | cut -d . -f 2)

    service_with_characteristic=$(./util/service_with_characteristic.sh "$aid" "$iid")
    polling=$(echo "$service_with_characteristic" | jq -r '.characteristics[0].polling // .polling // empty')

    if [ "$previous_value" = '' ] || { [ "$polling" != '' ] && [ "$age" -gt "$polling" ]; }; then
        logger_debug 'Reading new value'
        value=$(echo "$service_with_characteristic" | ./util/value_get.sh)
        responseValue=$?
        if [ $responseValue != 0 ]; then
            logger_error "Got response $responseValue polling $subscription_path"
        else
            if [ "$value" != "$previous_value" ] && test -f "$subscription_path"; then
                logger_debug "Creating event for $aid $iid"
                echo "$value" > "$subscription_path"
                tmpfile=$(mktemp /tmp/homekit.sh_poll.XXXXXX)
                ./util/event_create.sh "$aid" "$iid" "$value" > "$tmpfile"
                mv "$tmpfile" "./store/sessions/$session/events/$subscription.json"
            fi
        fi
    fi
fi
