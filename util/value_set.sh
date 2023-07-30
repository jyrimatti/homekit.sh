#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -I channel:nixos-23.05-small -p nix jq yq
set -euo pipefail
PS4='+ $(date "+%T.%3N ($LINENO) ")'

value=$1

while IFS=$'\n' read -r service_with_characteristic; do
    characteristic=$(echo "$service_with_characteristic" | jq -c '.characteristics[0]')
    cmd=$(echo "$service_with_characteristic" | jq -r '.cmd // empty')
    if [ "$cmd" == "" ]; then
        echo "'cmd' not set in service properties!" >&2
        exit 154
    fi

    timeout=$(echo "$service_with_characteristic" | jq -r '.timeout // $default' --arg default "$(cat ./config/default-timeout)")
    
    start=$(date +%s.%N)
    set +e
    timeout -v --kill-after=3 "$timeout" "./accessories/$cmd" Set "$(echo "$service_with_characteristic" | jq -r '.iid')" "$(echo "$characteristic" | jq -r '.iid')" "$value"
    responseValue=$?
    set -e
    if [ $responseValue -eq 124 ]; then
        echo "Command '$cmd Set' timed out" >&2
        exit 158
    elif [ $responseValue -ne 0 ]; then
        echo "Command '$cmd Set' failed" >&2
        exit $responseValue
    fi
    end=$(date +%s.%N)
    
    runtime=$(echo "$end - $start" | bc -l)
    echo "$cmd Set: ${runtime}s" >&2
done