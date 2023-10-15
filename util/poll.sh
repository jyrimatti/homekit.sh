#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash jq ncurses
. ./prefs
. ./log/logging
. ./profiling
set -eu

logger_trace 'util/poll.sh'

session="$1"
subscription="$2"

subscription_path="$HOMEKIT_SH_RUNTIME_DIR/sessions/$session/subscriptions/$subscription"
if test -f "$subscription_path"; then
    logger_debug "Polling $subscription_path"

    age="$(($(date +%s) - $(date +%s -r "$subscription_path")))"
    previous_value="$(cat "$subscription_path")"

    logger_debug "Got age $age"

    aid="$(echo "$subscription" | cut -d . -f 1)"
    iid="$(echo "$subscription" | cut -d . -f 2)"

    service_with_characteristic="$(dash ./util/service_with_characteristic.sh "$aid" "$iid")"
    polling="$(echo "$service_with_characteristic" | jq -r '.characteristics[0].polling // .polling // empty')"

    toString() {
        servicename="$(echo "$service_with_characteristic" | jq -r '.type' | xargs dash ./util/type_to_string.sh)"
        characteristicname="$(echo "$service_with_characteristic" | jq -r '.characteristics[0].type' | xargs dash ./util/type_to_string.sh)"
        echo "$aid.$iid ($servicename.$characteristicname)"
    }

    if [ "$previous_value" = '' ] || { [ "$polling" != '' ] && [ "$age" -gt "$polling" ]; }; then
        touch "$subscription_path"
        logger_debug 'Reading new value'
        set +e
        value="$(echo "$service_with_characteristic" | dash ./util/value_get.sh "$aid" "$iid")"
        responsevalue=$?
        set -e
        if [ $responsevalue = 158 ]; then
            logger_error "Got timeout while reading value for $(toString)"
        elif [ $responsevalue = 152 ]; then
            logger_error "Got empty response while reading value for $(toString)"
        elif [ $responsevalue != 0 ]; then
            logger_error "Got errorcode $responsevalue while reading value for $(toString)"
        else
            if [ "$(echo "$service_with_characteristic" | jq -c '.characteristics[0].format')" = 'string' ]; then
                logger_debug 'Value is a string -> wrap it in quotes if not already'
                value="$(echo "$value" | sed 's/^[^"].*[^"]$/"\0"/')"
            fi
            if [ "$value" != "$previous_value" ] && test -f "$subscription_path"; then
                logger_debug "Creating event for $aid $iid"
                echo "$value" > "$subscription_path"
                tmpfile="$(mktemp "$HOMEKIT_SH_RUNTIME_DIR/homekit.sh_poll.XXXXXX")"
                dash ./util/event_create.sh "$aid" "$iid" "$value" > "$tmpfile"
                mv "$tmpfile" "$HOMEKIT_SH_RUNTIME_DIR/sessions/$session/events/$subscription.json"
            fi
        fi
    fi
fi
