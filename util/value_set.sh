#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-24.11-small -p nix dash jq yq ncurses
. ./prelude
set -eu

logger_trace 'util/value_set.sh'

aid="$1"
iid="$2"
value="$3"

jq -r '[.type, .typeName, .iid, .characteristics[0].type, .characteristics[0].typeName, .characteristics[0].format, .characteristics[0].timeout // .timeout // " ", .characteristics[0].cmd // .cmd // " ", .characteristics[0].minValue // " ", .characteristics[0].maxValue // " ", .characteristics[0].minStep // " ", .characteristics[0].maxLen // " ", .characteristics[0].maxDataLen // " ", (.characteristics[0]["valid-values"] // [] | join(","))] | @tsv' |
while IFS=$(echo "\t") read -r servicetype serviceTypeName serviceiid characteristictype characteristicTypeName format timeout cmd minValue maxValue minStep maxLen maxDataLen validValues
do
    servicedata="{\"aid\": $aid, \"iid\": \"$serviceiid\", \"type\": \"$servicetype\", \"typeName\": \"$serviceTypeName\"}"
    characteristicdata="{\"type\": \"$characteristictype\", \"typeName\": \"$characteristicTypeName\", \"iid\": $iid}"
    for="for $servicedata and $characteristicdata"

    if [ "$cmd" = ' ' ]; then
        logger_error "Cannot set value, \"cmd\" not set in characteristic/service properties $for"
        exit 154
    fi

    if ! dash ./util/validate_value.sh "$value" "$format" "$minValue" "$maxValue" "$minStep" "$maxLen" "$maxDataLen" "$validValues"; then
        logger_error "Trying to set invalid '$value' $for"
        exit 153
    fi

    if [ "$timeout" = ' ' ]; then
        timeout="$HOMEKIT_SH_DEFAULT_TIMEOUT"
    fi

    logger_debug "Using timeout $timeout for $cmd Set $for"

    if [ -e /proc/uptime ]; then
        IFS= read -r start_accurate </proc/uptime
        start_accurate="${start_accurate%% *}"
    else
        start_accurate="$(date +%s.%2N)"
    fi
    start="${start_accurate%%.*}"
    set +e
    timeout -v --kill-after=0.5 "$timeout" dash -c "cd '$HOMEKIT_SH_ACCESSORIES_DIR'; $cmd Set '$servicedata' '$characteristicdata' '$value'"
    responseValue=$?
    set -e
    if [ -e /proc/uptime ]; then
        IFS= read -r end_accurate </proc/uptime
        end_accurate="${end_accurate%% *}"
    else
        end_accurate="$(date +%s.%2N)"
    fi
    end="${end_accurate%%.*}"

    duration="$((end - start))"
    if [ "$duration" -ge 3 ]; then
        logger_warn "$cmd Set in $(echo "$end_accurate - $start_accurate" | bc)s $for"
    elif [ logger_debug_enabled ]; then
        logger_debug "$cmd Set in $(echo "$end_accurate - $start_accurate" | bc)s $for"
    else
        logger_info "$cmd Set: ${duration}s $for"
    fi

    if [ "$responseValue" -eq 124 ]; then
        logger_error "Command '$cmd Set' timed out $for"
        exit 158
    elif [ "$responseValue" -ne 0 ]; then
        logger_error "Command '$cmd Set' failed $for"
        exit $responseValue
    fi
done
