#! /usr/bin/env nix-shell
#! nix-shell -i bash -I channel:nixos-23.05-small -p fswatch gnused
set -euo pipefail

while true
do
    ret=$(fswatch -1 accessories)
    if [ "$ret" = "" ]; then
        exit 1
    fi
    current=$(sed 's/c#=\([^ ]*\) .*/\1/' store/dns-txt)
    newval=$((current+1))
    echo "Updated configuration number $current -> $newval"
    sed -i "s/c#=[0-9]*/c#=$newval/" store/dns-txt
done
