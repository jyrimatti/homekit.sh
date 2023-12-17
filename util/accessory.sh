#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash findutils ncurses
. ./prefs
. ./log/logging
. ./profiling

set -eu

logger_trace 'util/accessory.sh'

aid="$1"

for f in $(find "$HOMEKIT_SH_ACCESSORIES_DIR" -name '*.toml'); do
    if [ "$(dash ./util/aid.sh "$f")" = "$aid" ]; then
        echo "$f"
        exit 0
    fi
done