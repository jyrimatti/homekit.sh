#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash coreutils jq yq bc ncurses
. ./logging
. ./profiling
set -eu

logger_trace 'util/value_get.sh'

aid="$1"
iid="$2"

if [ -n "${HOMEKIT_SH_CACHE_VALUES:-}" ]; then
    if [ -e "./store/cache/values" ]; then
        for i in $(find "./store/cache/values" -name "$aid.$iid" -mmin -$HOMEKIT_SH_CACHE_VALUES); do
            cat "./store/cache/values/$aid.$iid"
            logger_debug "Value for $aid.$iid retrived from cache"
            exit 0
        done
    fi
fi

toString() {
    servicename="$(dash ./util/type_to_string.sh "$1")"
    characteristicname="$(dash ./util/type_to_string.sh "$2")"
    echo "$aid.$iid ($servicename.$characteristicname)"
}

jq -r '[.type, .characteristics[0].type, .characteristics[0].format, .characteristics[0].timeout // .timeout // " ", .characteristics[0].value // " ", .characteristics[0].cmd // .cmd // " "] | @tsv' |
while IFS=$(echo "\t") read -r servicetype characteristictype format timeout value cmd
do
    if [ "$cmd" = ' ' ]; then
        if [ "$value" != ' ' ]; then
            logger_debug "No \"cmd\" set in characteristic/service properties for $(toString "$servicetype" "$characteristictype"), returning given constant value '$value'"
            if [ "$format" = 'string' ]; then
                echo "\"$value\""
            else
                echo "$value"
            fi
            exit 0
        else
            if [ "$servicetype" = '3E' ] && [ "$characteristictype" = '14' ]; then
                logger_debug "Returning null for $(toString "$servicetype" "$characteristictype") since Apple requires value field to be not present."
                echo 'null'
                exit 0
            else
                logger_error "No \"cmd\" or \"value\" set in characteristic/service properties for $(toString "$servicetype" "$characteristictype") -> leaving 'value' out"
                echo 'null'
                exit 154
            fi
        fi
    fi

    if [ "$timeout" = ' ' ]; then
        timeout="$(cat ./config/default-timeout)"
    fi

    logger_debug "Using timeout $timeout for $cmd Get for $(toString "$servicetype" "$characteristictype")"

    start="$(date +%s)"
    set +e
    ret="$(timeout -v --kill-after=3 "$timeout" dash -c "cd ./accessories; $cmd Get")"
    responseValue=$?
    set -e
    if [ "$responseValue" -eq 124 ]; then
        logger_error "Command '$cmd Get' timed out for $(toString "$servicetype" "$characteristictype")"
        exit 158
    elif [ "$responseValue" -ne 0 ]; then
        logger_error "Command '$cmd Get' failed for $(toString "$servicetype" "$characteristictype")"
        exit $responseValue
    elif [ "$ret" = '' ]; then
        logger_error "Command '$cmd Get' returned empty response for $(toString "$servicetype" "$characteristictype")"
        exit 152
    fi
    end="$(date +%s)"

    case $ret in
        '"'*'"') ;;
        *)
            if [ "$format" = 'string' ]; then
                logger_debug 'Value is a string -> wrap it in quotes if not already'
                ret="$(echo "$ret" | sed 's/^[^"].*[^"]$/"\0"/')"
            fi
            ;;
    esac

    if [ -n "${HOMEKIT_SH_CACHE_VALUES:-}" ]; then
        test -e "./store/cache/values" || mkdir -p ./store/cache/values
        echo "$ret" > "./store/cache/values/$aid.$iid"
    fi

    logger_info "$cmd Get in $((end - start))s returned: $ret for $aid.$iid"
    echo "$ret"
done