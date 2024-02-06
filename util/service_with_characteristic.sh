#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash jq yq ncurses
. ./prelude
set -eu

# Finds the characteristic with the given iid in the accessory with the given aid.
# Returns the characteristic surrounded by its service.

logger_trace 'util/service_with_characteristic.sh'

aid="$1"
iid="$2"

toml="$(dash ./util/find_accessory.sh "$aid")"

dash ./util/accessory.sh "$toml" \
    | jq -c ".services | .[] | .characteristics |= map(select(.iid == $iid)) | select(.characteristics | any)"
