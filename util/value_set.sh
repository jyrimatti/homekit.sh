#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash jq yq
. ./logging
. ./profiling
set -eu

logger_trace 'util/value_set.sh'

value="$1"

service_with_characteristic="$(cat)"
cmd=$(echo "$service_with_characteristic" | jq -re '.characteristics[0].cmd // .cmd') || {
    logger_error 'Cannot set value, "cmd" not set in characteristic/service properties!'
    exit 154
}

timeout=$(echo "$service_with_characteristic" | jq -r '.characteristics[0].timeout // .timeout // $default' --arg default "$(cat ./config/default-timeout)")
logger_debug "Using timeout $timeout"

serv="$(echo "$service_with_characteristic" | jq -r '.type' | xargs ./util/type_to_string.sh)"
char="$(echo "$service_with_characteristic" | jq -r '.characteristics[0].type' | xargs ./util/type_to_string.sh)"

start=$(date +%s)
set +e
timeout -v --kill-after=3 "$timeout" dash -c "cd ./accessories; $cmd Set '$serv' '$char'"
responseValue=$?
set -e
if [ $responseValue -eq 124 ]; then
    logger_error "Command '$cmd Set' timed out"
    exit 158
elif [ $responseValue -ne 0 ]; then
    logger_error "Command '$cmd Set' failed"
    exit $responseValue
fi
end=$(date +%s)

logger_info "$cmd Set: $((end - start))s"
