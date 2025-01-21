#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-24.11-small -p dash fswatch avahi yq
. ./prelude
set -eu

dash ./util/bridges.sh \
    | {
        while read -r port bridge username; do {
            if [ "$port" = "" ]; then
                dash ./broadcast-single.sh "$HOMEKIT_SH_PORT" &
            else
                dash ./broadcast-single.sh "$port" "${bridge:-$port}" &
            fi
        } done
        wait $(jobs -p)
      }
