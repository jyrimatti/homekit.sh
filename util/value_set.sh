#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash jq yq ncurses
. ./logging
. ./profiling
set -eu

logger_trace 'util/value_set.sh'

aid="$1"
iid="$2"
value="$3"

if [ -n "${HOMEKIT_SH_CACHE_VALUES:-}" ]; then
    rm -f "./store/cache/values/$aid.$iid"
fi

service_with_characteristic="$(cat)"
servicename="$(echo "$service_with_characteristic" | jq -r '.type' | xargs dash ./util/type_to_string.sh)"
characteristicname="$(echo "$service_with_characteristic" | jq -r '.characteristics[0].type' | xargs dash ./util/type_to_string.sh)"
cmd="$(echo "$service_with_characteristic" | jq -re '.characteristics[0].cmd // .cmd')" || {
    logger_error "Cannot set value, \"cmd\" not set in characteristic/service properties for $characteristicname@$servicename"
    exit 154
}

timeout="$(echo "$service_with_characteristic" | jq -r '.characteristics[0].timeout // .timeout // $default' --arg default "$(cat ./config/default-timeout)")"
logger_debug "Using timeout $timeout"

start="$(date +%s)"
set +e
timeout -v --kill-after=3 "$timeout" dash -c "cd ./accessories; $cmd Set '$servicename' '$characteristicname' '$value'"
responseValue=$?
set -e
if [ $responseValue -eq 124 ]; then
    logger_error "Command '$cmd Set' timed out for $characteristicname@$servicename"
    exit 158
elif [ $responseValue -ne 0 ]; then
    logger_error "Command '$cmd Set' failed for $characteristicname@$servicename"
    exit $responseValue
fi
end="$(date +%s)"

logger_info "$cmd Set: $((end - start))s for $characteristicname@$servicename"
