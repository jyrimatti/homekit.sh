#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash jq yq
. ./logging
. ./profiling

set -eu

logger_trace 'util/iid_service.sh'

# use Service InstanceID from json if provided, or use its typecode converted to decimal + 10000 + $offset*1000

servicejson="$1"
typecode="${2:-}"
offset="${3:-1}" # index of this service amongst other services of the same type

if [ -z "$typecode" ]; then
    logger_debug 'No typecode given -> reading from service config'
    typecode=$(echo "$servicejson" | jq -r '.type' | xargs ./util/typecode_service.sh)
fi
logger_debug "Got typecode $typecode. Using offset $offset"

echo "$servicejson" | jq -ce "include \"util\";.iid // if .type == \"AccessoryInformation\" then 1 else 10000 * (\"$typecode\" | to_i(16)) + $offset*1000 end"
