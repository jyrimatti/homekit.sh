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

toString() {
    servicename="$(dash ./util/type_to_string.sh "$1")"
    characteristicname="$(dash ./util/type_to_string.sh "$2")"
    echo "$aid.$iid ($servicename.$characteristicname)"
}

jq -r '[.type, .characteristics[0].type, .characteristics[0].timeout // .timeout // " ", .characteristics[0].value // " ", .characteristics[0].cmd // .cmd // " "] | @tsv' |
while IFS=$(echo "\t") read -r servicetype characteristictype timeout value cmd
do
    if [ "$cmd" = ' ' ]; then
        logger_error "Cannot set value, \"cmd\" not set in characteristic/service properties for $(toString "$servicetype" "$characteristictype")"
        exit 154
    fi

    if [ "$timeout" = ' ' ]; then
        timeout="$(cat ./config/default-timeout)"
    fi

    logger_debug "Using timeout $timeout for $cmd Set for $(toString "$servicetype" "$characteristictype")"

    start="$(date +%s)"
    set +e
    timeout -v --kill-after=3 "$timeout" dash -c "cd ./accessories; $cmd Set '' '' '$value'"
    responseValue=$?
    set -e
    if [ "$responseValue" -eq 124 ]; then
        logger_error "Command '$cmd Set' timed out for $(toString "$servicetype" "$characteristictype")"
        exit 158
    elif [ "$responseValue" -ne 0 ]; then
        logger_error "Command '$cmd Set' failed for $(toString "$servicetype" "$characteristictype")"
        exit $responseValue
    fi
    end="$(date +%s)"

    logger_info "$cmd Set: $((end - start))s for $(toString "$servicetype" "$characteristictype")"
done
