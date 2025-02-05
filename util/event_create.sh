#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-24.11-small -p dash jq ncurses
. ./prelude
set -eu

logger_trace 'util/event_create.sh'

aid="$1"
iid="$2"
value="$3"

jq -jcn "{ characteristics: [{ aid: $aid, iid: $iid, value: \$value }] }" --argjson value "$value"