#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p dash jq
. ./logging
. ./profiling
set -eu

logger_trace 'util/event_create.sh'

aid="$1"
iid="$2"
value="$3"

jq -cn "{ characteristics: [{ aid: $aid, iid: $iid, value: \$value }] }" --argjson value "$value"