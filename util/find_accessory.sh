#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash findutils ncurses
. ./prelude

set -eu

logger_trace 'util/find_accessory.sh'

aid="$1"

find "$HOMEKIT_SH_ACCESSORIES_DIR" -name '*.toml' | while read -r f; do
    if [ "$(dash ./util/aid.sh "$f")" = "$aid" ]; then
        echo "$f"
        break
    fi
done