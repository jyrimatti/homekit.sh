#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -I channel:nixos-23.05-small -p nix jq yq
set -euo pipefail
PS4='+ $(date "+%T.%3N ($LINENO) ")'

# use Service InstanceID from json if provided, or use its typecode converted to decimal + 10000 + $offset*1000

servicejson=$1
typecode=${2:-}
offset=${3:-1} # index of this service amongst other services of the same type

if [ "$typecode" == "" ]; then
    type=$(echo "$servicejson" | jq -r '.type')
    typecode=$(tomlq '.' config/services/*.toml | jq -s add | jq -e ".$type.type")
fi

echo "$servicejson" | jq -e "include \"util\";.iid // if .type == \"AccessoryInformation\" then 1 else 10000 * (\"$typecode\" | to_i(16)) + $offset*1000 end"
