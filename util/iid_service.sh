#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash jq yq ncurses
. ./prelude

set -eu

logger_trace 'util/iid_service.sh'

# use Service InstanceID from json if provided, or use its typecode (first 8 chars) converted to decimal + 10000 + $offset*1000

servicejson="$1"
typecode="$2"
index="$3" # index of this service amongst other services of the same type

prefix=$(printf '%.8s' "$typecode")

calculated="$((10000 * $(printf "%d\n" 0x"$prefix") + 1000 * index))"
echo "$servicejson" | jq -ce ".iid // if .type == \"AccessoryInformation\" then 1 else $calculated end"
