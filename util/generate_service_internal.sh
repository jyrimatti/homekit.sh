#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash coreutils jq ncurses sqlite3
. ./prefs
. ./log/logging
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
        "./bin/rust-parallel-$(uname)" -r '.*' --jobs "${PROFILING:-$HOMEKIT_SH_PARALLELISM}" dash -c "echo '{0}' | jq -c '.characteristics[0] | (.value = (\$value // .defaultValue // .minValue // .[\"valid-values\"][0] // (if .format == \"bool\" and .type != \"14\" then false elif .format == \"string\" then \"\" else empty end))) // .' --argjson value \"\$(echo '{0}' | dash ./util/value_get.sh $aid \$(echo '{0}' | jq -r .characteristics[0].iid) || echo null)\""
    else
         jq -c '.characteristics[0]'
    fi
}

populateevent() {
    jq -c 'if has("polling") then . else . + {"ev": false} end'
}

find_characteristic() {
    if [ -e "${HOMEKIT_SH_CACHE_TOML_SQLITE:-}" ]; then
        logger_debug 'Using SQLite cached characteristics'
        values="$(jq -c '.characteristics | map_values(. | objects // {value: .})')"
        typeNames="$(echo "$values" | jq -r 'keys_unsorted | @csv' | tr '"' "'")"
        sqlite3 -readonly "$HOMEKIT_SH_CACHE_TOML_SQLITE" '.mode json' "SELECT typeName, typeCode type, perms, format, minValue, maxValue, minStep, maxLen, unit, validvalues 'valid-values' FROM characteristics WHERE typeName IN ($typeNames)"\
         | jq -c '(map({ (.typeName): (. | del(.typeName) | with_entries(if .value == "" then empty elif .key == "minValue" or .key == "maxValue" or .key == "minStep" then (.value |= tonumber) elif .key == "perms" or .key == "valid-values" then (.value |= split(",") ) else . end) ) }) | add) * $values | .[]' --argjson values "$values"
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
     | populateevent\
     | jq -cs "\$service + {typeName: \"$serviceTypeName\", type: \"$typecode\", iid: $service_iid, characteristics: .}" --argjson service "$service"
} || {
    logger_error 'Could not generate characteristics: check config/characteristic/*.toml'
    exit 1
}
