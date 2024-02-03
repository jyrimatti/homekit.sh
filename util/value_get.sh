#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash coreutils jq yq bc ncurses
. ./prelude
set -eu

logger_trace 'util/value_get.sh'

aid="$1"
iid="$2"
onlyconstants="${3:-0}"

if [ "${HOMEKIT_SH_CACHE_VALUES:-0}" != "0" ]; then
    if [ -e "$HOMEKIT_SH_CACHE_DIR/values" ]; then
        for i in $(find "$HOMEKIT_SH_CACHE_DIR/values" -name "$aid.$iid" -mmin -$HOMEKIT_SH_CACHE_VALUES); do
            cat "$HOMEKIT_SH_CACHE_DIR/values/$aid.$iid"
            logger_debug "Value for $aid.$iid retrived from cache"
            exit 0
        done
    fi
fi

jq -r '[.type, .characteristics[0].type, .characteristics[0].format, .characteristics[0].timeout // .timeout // " ", .characteristics[0].value // " ", .characteristics[0].cmd // .cmd // " "] | @tsv' |
while IFS=$(echo "\t") read -r servicetype characteristictype format timeout value cmd
do
    if [ "$cmd" = ' ' ]; then
        if [ "$value" != ' ' ]; then
            logger_debug "No \"cmd\" set in characteristic/service properties for $aid.$iid ($servicetype.$characteristictype), returning given constant value '$value'"
            if [ "$format" = 'string' ]; then
                echo "\"$value\""
            else
                echo "$value"
            fi
            exit 0
        else
            if [ "$servicetype" = '3E' ] && [ "$characteristictype" = '14' ]; then
                logger_debug "Returning null for $aid.$iid ($servicetype.$characteristictype) since Apple requires value field to be not present."
                echo 'null'
                exit 0
            else
                logger_error "No \"cmd\" or \"value\" set in characteristic/service properties for $aid.$iid ($servicetype.$characteristictype) -> leaving 'value' out"
                echo 'null'
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
    servicename="$(dash ./util/type_to_string.sh "$servicetype")"
    characteristicname="$(dash ./util/type_to_string.sh "$characteristictype")"

    start="$(date +%s)"
    set +e
    ret="$(timeout -v --kill-after=3 "$timeout" dash -c "cd '$HOMEKIT_SH_ACCESSORIES_DIR'; $cmd Get '$servicename' '$characteristicname'")"
    responseValue=$?
    set -e
    end="$(date +%s)"
    duration="$((end - start))"
    if [ "$responseValue" -eq 124 ]; then
        logger_error "Command '$cmd Get' timed out in ${duration}s for $aid.$iid ($servicetype.$characteristictype)"
        exit 158
    elif [ "$responseValue" -ne 0 ]; then
        logger_error "Command '$cmd Get' failed for $aid.$iid ($servicetype.$characteristictype)"
        exit $responseValue
    elif [ "$ret" = '' ]; then
        logger_error "Command '$cmd Get' returned empty response for $aid.$iid ($servicetype.$characteristictype)"
        exit 152
    fi

    case $ret in
        '"'*'"') ;;
        *)
            if [ "$format" = 'string' ]; then
                logger_debug 'Value is a string -> wrap it in quotes if not already'
                ret="$(echo "$ret" | sed 's/^[^"].*[^"]$/"\0"/')"
            fi
            ;;
    esac

    if [ "${HOMEKIT_SH_CACHE_VALUES:-0}" != "0" ]; then
        test -e "$HOMEKIT_SH_CACHE_DIR/values" || mkdir -p "$HOMEKIT_SH_CACHE_DIR"/values
        echo "$ret" > "$HOMEKIT_SH_CACHE_DIR/values/$aid.$iid"
    fi

    logger_info "$cmd Get in ${duration}s returned: $ret for $aid.$iid"
    echo "$ret"
done