#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash findutils ncurses
. ./prefs
. ./logging
. ./profiling

set -eu

logger_trace 'util/accessory.sh'

aid="$1"

for f in $(find ./accessories -name '*.toml'); do
    if [ "$(dash ./util/aid.sh "$f")" = "$aid" ]; then
        echo "$f"
        exit 0
    fi
done