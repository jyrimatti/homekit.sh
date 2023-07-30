#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -I channel:nixos-23.05-small -p nix jq
set -euo pipefail

while true
do
    ./util/poll.sh
    sleep 1
done
