#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash jq yq ncurses
. ./prelude
set -eu

logger_trace 'util/value_set.sh'

aid="$1"
iid="$2"
value="$3"

if [ "${HOMEKIT_SH_CACHE_VALUES:-0}" != "0" ]; then
    rm -f "$HOMEKIT_SH_CACHE_DIR/values/$aid.$iid"
fi

jq -r '[.type, .characteristics[0].type, .characteristics[0].timeout // .timeout // " ", .characteristics[0].value // " ", .characteristics[0].cmd // .cmd // " "] | @tsv' |
while IFS=$(echo "\t") read -r servicetype characteristictype timeout value cmd
do
    if [ "$cmd" = ' ' ]; then
        logger_error "Cannot set value, \"cmd\" not set in characteristic/service properties for $aid.$iid ($servicetype.$characteristictype)"
        exit 154
    fi

    if [ "$timeout" = ' ' ]; then
        timeout="$HOMEKIT_SH_DEFAULT_TIMEOUT"
    fi

    logger_debug "Using timeout $timeout for $cmd Set for $aid.$iid ($servicetype.$characteristictype)"

    if [ -e /proc/uptime ]; then
        IFS= read -r start_accurate </proc/uptime
        start_accurate="${start_accurate%% *}"
    else
        start_accurate="$(date +%s.%2N)"
    fi
    start="${start_accurate%%.*}"
    set +e
    timeout -v --kill-after=3 "$timeout" dash -c "cd '$HOMEKIT_SH_ACCESSORIES_DIR'; $cmd Set '$servicetype' '$characteristictype' '$value'"
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
        logger_warn "$cmd Set in $(echo "$end_accurate - $start_accurate" | bc)s for $aid.$iid ($servicetype.$characteristictype)"
    elif [ logger_debug_enabled ]; then
        logger_debug "$cmd Set in $(echo "$end_accurate - $start_accurate" | bc)s for $aid.$iid ($servicetype.$characteristictype)"
    else
        logger_info "$cmd Set: ${duration}s for $aid.$iid ($servicetype.$characteristictype)"
    fi

    if [ "$responseValue" -eq 124 ]; then
        logger_error "Command '$cmd Set' timed out for $aid.$iid ($servicetype.$characteristictype)"
        exit 158
    elif [ "$responseValue" -ne 0 ]; then
        logger_error "Command '$cmd Set' failed for $aid.$iid ($servicetype.$characteristictype)"
        exit $responseValue
    fi
done
