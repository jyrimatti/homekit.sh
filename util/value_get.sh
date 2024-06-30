#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash coreutils jq yq bc ncurses
. ./prelude
set -eu

logger_trace 'util/value_get.sh'

aid="$1"
iid="$2"
onlyconstants="${3:-0}"

jq -r '[.type, .typeName, .iid, .characteristics[0].type, .characteristics[0].typeName, .characteristics[0].format, .characteristics[0].timeout // .timeout // " ", if .characteristics[0].value == false then false else .characteristics[0].value // " " end, .characteristics[0].cmd // .cmd // " ", .characteristics[0].minValue // " ", .characteristics[0].maxValue // " ", .characteristics[0].minStep // " ", .characteristics[0].maxLen // " ", .characteristics[0].maxDataLen // " ", (.characteristics[0]["valid-values"] // [] | join(","))] | @tsv' \
  | while IFS=$(echo "\t") read -r servicetype serviceTypeName serviceiid characteristictype characteristicTypeName format timeout value cmd minValue maxValue minStep maxLen maxDataLen validValues; do
        servicedata="{\"aid\": $aid, \"iid\": \"$serviceiid\", \"type\": \"$servicetype\", \"typeName\": \"$serviceTypeName\"}"
        characteristicdata="{\"type\": \"$characteristictype\", \"typeName\": \"$characteristicTypeName\", \"iid\": $iid}"
        for="for $servicedata and $characteristicdata"

        if [ "$cmd" = ' ' ]; then
            if [ "$value" != ' ' ]; then
                logger_debug "No \"cmd\" set in characteristic/service properties $for, returning given constant value '$value'"
                if [ "$format" = 'string' ]; then
                    echo "\"$value\""
                else
                    echo "$value"
                fi
                exit 0
            else
                if [ "$servicetype" = '3E' ] && [ "$characteristictype" = '14' ]; then
                    logger_debug "Returning null $for since Apple requires value field to be not present."
                    echo 'null'
                    exit 0
                else
                    logger_error "No \"cmd\" or \"value\" set in characteristic/service properties $for -> leaving 'value' out"
                    exit 154
                fi
            fi
        fi

        if [ "$onlyconstants" = '1' ]; then
            logger_debug "Skipping $aid.$iid ($servicetype.$characteristictype) since it is not a constant"
            echo null
            exit 0
        fi

        if [ "$timeout" = ' ' ]; then
            timeout="${HOMEKIT_SH_TIMEOUT:-}"
        fi
        if [ "$timeout" = '' ]; then
            timeout="$HOMEKIT_SH_DEFAULT_TIMEOUT"
        fi

        logger_debug "Using timeout $timeout for $cmd Get for $aid.$iid ($servicetype.$characteristictype)"

        if [ -e /proc/uptime ]; then
            IFS= read -r start_accurate </proc/uptime
            start_accurate="${start_accurate%% *}"
        else
            start_accurate="$(date +%s.%2N)"
        fi
        start="${start_accurate%%.*}"
        set +e
        ret="$(timeout -v --kill-after=3 "$timeout" dash -c "cd '$HOMEKIT_SH_ACCESSORIES_DIR'; $cmd Get '$servicedata' '$characteristicdata'")"
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
            logger_warn "$cmd Get in $(echo "$end_accurate - $start_accurate" | bc)s returned: $ret $for"
        elif [ logger_debug_enabled ]; then
            logger_debug "$cmd Get in $(echo "$end_accurate - $start_accurate" | bc)s returned: $ret $for"
        else
            logger_info "$cmd Get in ${duration}s returned: $ret $for"
        fi

        if [ "$responseValue" -eq 124 ]; then
            logger_error "Command '$cmd Get' timed out in ${duration}s $for"
            exit 158
        elif [ "$responseValue" -ne 0 ]; then
            logger_error "Command '$cmd Get' failed $for"
            exit $responseValue
        elif [ "$ret" = '' ]; then
            logger_error "Command '$cmd Get' returned empty response $for"
            exit 152
        elif ! dash ./util/validate_value.sh "$ret" "$format" "$minValue" "$maxValue" "$minStep" "$maxLen" "$maxDataLen" "$validValues"; then
            logger_error "Command '$cmd Get' returned invalid response '$ret' $for"
            exit 153
        fi

        case $ret in
            '"'*'"') ;;
            *)
                if [ "$format" = 'string' ]; then
                    logger_debug 'Value is a string without quotes -> wrap it in quotes'
                    ret="\"$ret\""
                fi
                ;;
        esac

        echo "$ret"
done