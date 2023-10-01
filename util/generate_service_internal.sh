#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash coreutils jq ncurses
. ./logging
. ./profiling
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
    jq -c "include \"util\"; \$service + {type: \"$typecode\", characteristics: [. + {iid: (.iid // $service_iid + (.type | to_i(16)))}]}" --argjson service "$service"
}

populatevalue() {
    withvalue="$1"
    aid="$2"
    if [ "$withvalue" = '1' ]; then
        "./bin/rust-parallel-$(uname)" -r '.*' --jobs "${PROFILING:-32}" dash -c "echo '{0}' | jq -c '.characteristics[0] | (.value = (\$value // .defaultValue // .minValue // .[\"valid-values\"][0] // (if .format == \"bool\" and .type != \"14\" then false elif .format == \"string\" then \"\" else empty end))) // .' --argjson value \"\$(echo '{0}' | dash ./util/value_get.sh $aid \$(echo '{0}' | jq -r .characteristics[0].iid) || echo null)\""
    else
         jq -c '.characteristics[0]'
    fi
}

{
    echo "$service" |
    jq -cr '.characteristics | keys_unsorted[] as $k | "first(select(.[\"\($k)\"]))''[\"\($k)\"] + \((.[$k]|objects // {value:.}) + {typeName: $k})" | @sh' |
    xargs dash ./util/characteristic.sh |
    characteristic_with_id_and_service |
    populatevalue "$withvalue" "$aid" |
    jq -cs "\$service + {typeName: \"$serviceTypeName\", type: \"$typecode\", iid: $service_iid, characteristics: .}" --argjson service "$service"
} || {
    logger_error 'Could not generate characteristics: check config/characteristic/*.toml'
    exit 1
}
