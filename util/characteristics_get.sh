#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -I channel:nixos-23.05-small -p nix jq yq
set -euo pipefail
PS4='+ $(date "+%T.%3N ($LINENO) ")'

resource_does_not_exist=-70409

meta=$1
perms=$2
type=$3
ev=$4
id=$5

aid=$(echo "$id" | sed 's/\([^.]*\).*/\1/')
iid=$(echo "$id" | sed 's/[^.]*[.]\(.*\)/\1/')

ret=$(jq -n "{ aid: $aid, iid: $iid }")

service_with_characteristic=$(./util/service_with_characteristic.sh "$aid" "$iid" || echo "")
if [ "$service_with_characteristic" == "" ]; then
    echo "$ret" | jq ". + { status: $resource_does_not_exist }"
    exit 0
fi

characteristic=$(echo "$service_with_characteristic" | jq -c '.characteristics[0]')

if [ "$meta" == "1" ]; then
    extra=$(echo "$characteristic" | jq '{format, unit, minValue, maxValue, minStep, maxLen}')
    ret=$(echo "$ret" | jq '. + $extra' --argjson extra "$extra")
fi
for e in perms type ev; do
    if [ "${!e}" == "1" ]; then
        extra=$(echo "$characteristic" | jq "{$e}")
        ret=$(echo "$ret" | jq '. + $extra' --argjson extra "$extra")
    fi
done


value=""
cmd=$(echo "$service_with_characteristic" | jq '.cmd // empty')
if [ ! "$cmd" == "" ]; then
    # cmd provided for the service -> try to read value from cmd
    value=$(echo "$service_with_characteristic" | ./util/value_get.sh)
    if [ "$(echo "$characteristic" | jq '.format')" == "string" ]; then
        # value is a string -> wrap it in quotes if not already
        value=$(echo "$value" | sed 's/^[^"].*[^"]$/"\0"/')
    fi
fi
if [ "$value" == "" ]; then
    # no value from cmd -> take the constant defined in configuration
    value=$(echo "$characteristic" | jq '.value')
fi
ret=$(echo "$ret" | jq '. + { value: $value }' --argjson value "$value")

echo "$ret" | jq 'with_entries(if .value == null then empty else . end)'