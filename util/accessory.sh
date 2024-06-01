#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash findutils ncurses jq yq
. ./prelude

set -eu

logger_trace 'util/accessory.sh'

toml="$1"

aid="$(dash ./util/aid.sh "$toml")"

if [ "${HOMEKIT_SH_CACHE_TOML_ACCESSORIES:-false}" = "true" ]; then
  jq -cs "{ aid: $aid, services: map({type, iid, characteristics}) }" "$HOMEKIT_SH_CACHE_DIR/$toml/accessory.json"
  logger_debug "Accessory $aid retrived from cache"
else
  dash ./util/services_grouped_by_type.sh "$toml" \
    | tr '\n' '\0' \
    | xargs -0 -n1 dash ./util/generate_service.sh 1 "$aid" \
    | jq -cs "{ aid: $aid, services: map({type, iid, characteristics}) }"
fi
