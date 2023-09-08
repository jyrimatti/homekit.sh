#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash coreutils jq yq bc ncurses
. ./logging
. ./profiling
set -eu

logger_trace 'util/value_get.sh'

service_with_characteristic="$(cat)"
aid="$1"
iid="$2"
servicename="$3"
characteristicname="$4"

if [ -n "${HOMEKIT_SH_CACHE_VALUES:-}" ]; then
    for i in $(find "./store/cache/values" -name "$aid.$iid" -mmin -$HOMEKIT_SH_CACHE_VALUES); do
        cat "./store/cache/values/$aid.$iid"
        logger_debug "Value for $aid.$iid retrived from cache"
        exit 0
    done
fi

cmd="$(echo "$service_with_characteristic" | jq -re '.characteristics[0].cmd // .cmd')" || {
    logger_debug "Cannot get value, \"cmd\" not set in characteristic/service properties for $characteristicname@$servicename in $service_with_characteristic"
    exit 154
}

timeout="$(echo "$service_with_characteristic" | jq -r '.characteristics[0].timeout // .timeout // $default' --arg default "$(cat ./config/default-timeout)")"
logger_debug "Using timeout $timeout for $cmd Get '$servicename' '$characteristicname'"

start="$(date +%s)"
set +e
ret="$(timeout -v --kill-after=3 "$timeout" dash -c "cd ./accessories; $cmd Get '$servicename' '$characteristicname'")"
responseValue=$?
set -e
if [ $responseValue -eq 124 ]; then
    logger_error "Command '$cmd Get' timed out for $characteristicname@$servicename"
    exit 158
elif [ $responseValue -ne 0 ]; then
    logger_error "Command '$cmd Get' failed for $characteristicname@$servicename"
    exit $responseValue
elif [ "$ret" = '' ]; then
    logger_error "Command '$cmd Get' returned empty response for $characteristicname@$servicename"
    exit 152
fi
end="$(date +%s)"

if [ -n "${HOMEKIT_SH_CACHE_VALUES:-}" ]; then
    mkdir -p ./store/cache/values
    echo "$ret" > "./store/cache/values/$aid.$iid"
fi

logger_info "$cmd Get in $((end - start))s returned: $ret for $characteristicname@$servicename"
echo "$ret"
