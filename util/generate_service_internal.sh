#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-24.11-small -p nix dash coreutils jq ncurses
. ./prelude
set -eu

logger_trace 'util/generate_service_internal.sh'

withvalue="$1"
aid="$2"
index="$3"
service="$(cat)"

serviceTypeName="$(echo "$service" | jq -r '.type')"
typecode="$(dash ./util/typecode_service.sh "$serviceTypeName")"
service_iid="$(dash ./util/iid_service.sh "$service" "$typecode" "$index")"

characteristic_with_id_and_service() {
    # as Characteristic InstanceID, use its typecode converted to decimal and added to the Service InstanceID
    jq -c "include \"util\"; \$service + {type: \"$typecode\", typeName: \"$serviceTypeName\", iid: $service_iid, characteristics: [. + {iid: (.iid // $service_iid + (.type | .[:8] | to_i(16)))}]}" --argjson service "$service"
}

populatevalue() {
    withvalue="$1"
    aid="$2"
    if [ "$withvalue" = '1' ]; then
        while read -r line; do
            iid="$(jq -nr '$in | .characteristics[0].iid' --argjson in "$line")"
            value="$(echo "$line" | dash ./util/value_get.sh "$aid" "$iid" 1 || echo null)"
            jq -nc '$in | .characteristics[0] | . + {"ev": (has("polling") or (.perms | index("ev")))}
                                           | (.value = ($value //
                                                        .defaultValue //
                                                        .minValue //
                                                        .["valid-values"][0] //
                                                        (  if .format == "bool" and .type != "14" then false
                                                         elif .format == "float" then 0
                                                         elif .format == "int" then 0
                                                         elif .format == "uint8" then 0
                                                         elif .format == "uint16" then 0
                                                         elif .format == "uint32" then 0
                                                         elif .format == "string" then ""
                                                         elif .format == "data" then ""
                                                         else empty end))) // .' \
                  --argjson value "$value" \
                  --argjson in "$line"
        done
    else
        jq -c '.characteristics[0] | . + {"ev": (has("polling") or (.perms | index("ev")))}'
    fi
}

find_characteristic() {
    if [ "${HOMEKIT_SH_CACHE_TOML_FS:-false}" = "true" ]; then
        logger_debug 'Using FS cached characteristics'
        jq -r '.characteristics | keys_unsorted[] as $k | [$k, (.[$k] | objects // {value: .} | tostring)] | @sh' | while IFS="'" read -r a b c d; do
          dash ./util/characteristic.sh "$b" "$d"
        done
    else
        jq -cr '.characteristics | keys_unsorted[] as $k | "first(select(.[\"\($k)\"]))''[\"\($k)\"] + \((.[$k]|objects // {value:.}) + {typeName: $k})" | @sh'\
         | xargs dash ./util/characteristic.sh
    fi
}

{
    echo "$service"\
     | find_characteristic\
     | characteristic_with_id_and_service\
     | populatevalue "$withvalue" "$aid"\
     | jq -cs "\$service + {type: \"$typecode\", typeName: \"$serviceTypeName\", iid: $service_iid, characteristics: .}" --argjson service "$service"
} || {
    logger_error 'Could not generate characteristics: check config/characteristics/*.toml'
    exit 1
}
