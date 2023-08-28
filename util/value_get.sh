#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash coreutils jq yq bc ncurses
. ./logging
. ./profiling
set -eu

logger_trace 'util/value_get.sh'

service_with_characteristic="$(cat)"
servicename="$(echo "$service_with_characteristic" | jq -r '.type' | xargs dash ./util/type_to_string.sh)"
characteristicname="$(echo "$service_with_characteristic" | jq -r '.characteristics[0].type' | xargs dash ./util/type_to_string.sh)"

cmd="$(echo "$service_with_characteristic" | jq -re '.characteristics[0].cmd // .cmd')" || {
    logger_debug "Cannot get value, \"cmd\" not set in characteristic/service properties for $characteristicname@$servicename in $service_with_characteristic"
    exit 154
}

timeout="$(echo "$service_with_characteristic" | jq -r '.characteristics[0].timeout // .timeout // $default' --arg default "$(cat ./config/default-timeout)")"
logger_debug "Using timeout $timeout"

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

logger_info "$cmd Get in $((end - start))s returned: $ret for $characteristicname@$servicename"
echo "$ret"
