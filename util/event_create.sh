#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -I channel:nixos-23.05-small -p bash jq
set -euo pipefail
PS4='+ $(date "+%T.%3N ($LINENO) ")'

aid=$1
iid=$2
value=$3

jq -n "{ characteristics: [{ aid: $aid, iid: $iid, value: \$value }] }" --argjson value "$value"