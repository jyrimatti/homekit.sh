#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -I channel:nixos-23.05-small -p nix jq
set -euo pipefail
PS4='+ $(date "+%T.%3N ($LINENO) ")'

for f in ./store/sessions/*; do
    for s in "$f"/subscriptions/*; do
        if test -f "$s"; then
            aid=$(basename "$s" | sed 's/\([^.]*\).*/\1/')
            iid=$(basename "$s" | sed 's/[^.]*[.]\(.*\)/\1/')

            service_with_characteristic=$(./util/service_with_characteristic.sh "$aid" "$iid")
            polling=$(echo "$service_with_characteristic" | jq -r '.polling // empty')

            age=$(($(date +%s) - $(date +%s -r "$s")))
            if [ "$polling" != "" ] && [ "$age" -gt "$polling" ]; then
                value=$(echo "$service_with_characteristic" | ./util/value_get.sh)
                responseValue=$?
                if [ $responseValue != 0 ]; then
                    echo "Error $responseValue polling $s" >&2
                else
                    previous_value=$(cat "$s")
                    if [ "$value" != "$previous_value" ]; then
                        echo "$value" > "$s"
                        ./util/event_create.sh "$aid" "$iid" "$value" > "$f/events/$aid.$iid.json"
                    fi
                fi
            fi
        fi
    done
done