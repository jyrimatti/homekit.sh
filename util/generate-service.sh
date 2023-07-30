#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -I channel:nixos-23.05-small -p nix jq yq
set -euo pipefail
PS4='+ $(date "+%T.%3N ($LINENO) ")'

declare -A typemap

while IFS=$'\n' read -r service; do
    type=$(echo "$service" | jq -r '.type')
    typecode=$(tomlq '.' config/services/*.toml | jq -s add | jq -re ".$type.type")

    typemap[$typecode]=$((${typemap[$typecode]:-0} + 1))

    service_iid=$(./util/iid_service.sh "$service" "$typecode" "${typemap[$typecode]}")

    characteristics=$(echo "$service" |\
                    jq -r '.characteristics | keys_unsorted[] as $k | ".[\"\($k)\"] + \(.[$k]|objects // {value:.})"' |\
                    sed "s#\(.*\)#tomlq '.' config/characteristics/*.toml | jq -s add | jq -e \'\1\'#" |\
                    sh) || (echo "Could not generate characteristics: check config/characteristic/*.toml" >&2 && exit 1)

    # as Characteristic InstanceID, use its typecode converted to decimal and added to the Service InstanceID
    characteristics_with_iid=$(echo "$characteristics" |\
        jq -s "include \"util\"; .[] | . += {iid: (.iid // $service_iid + (.type | to_i(16)))}" |\
        jq -s)

    ret=$(echo "$service" | jq ". + {type: \"$typecode\", iid: $service_iid, characteristics: \$newchars }" --argjson newchars "$characteristics_with_iid")
    echo "$ret"
done