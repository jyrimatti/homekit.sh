#! /usr/bin/env nix-shell
#! nix-shell -i bash -I channel:nixos-23.05-small -p fswatch avahi
set -eu

while true
do
    if command -v dns-sd >/dev/null; then
        dns-sd -R homekit.sh _hap._tcp . "$(cat ./config/port)" $(cat ./store/dns-txt) &
    else
        avahi-publish -s homekit.sh _hap._tcp "$(cat ./config/port)" $(cat ./store/dns-txt) &
    fi
    DNSSD_PID=$!

    trap 'kill $DNSSD_PID' EXIT

    ret=$(fswatch -1 ./store/dns-txt)
    kill $DNSSD_PID
    if [ "$ret" = "" ]; then
        exit 1
    fi
done
