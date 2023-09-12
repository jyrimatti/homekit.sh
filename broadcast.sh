#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p dash fswatch avahi
. ./logging
. ./profiling
set -eu

while true
do
    if command -v dns-sd >/dev/null; then
        logger_info "Broadcasting with dns-sd"
        dns-sd -R homekit.sh _hap._tcp . "$(cat ./config/port)" $(cat ./store/dns-txt) &
    else
        logger_info "Broadcasting with avahi"
        avahi-publish -s homekit.sh _hap._tcp "$(cat ./config/port)" $(cat ./store/dns-txt) &
    fi
    DNSSD_PID=$!

    trap 'kill $DNSSD_PID' EXIT

    ret="$(fswatch -1 -m poll_monitor ./store/dns-txt)"
    logger_info "dns-txt was modified"
    kill $DNSSD_PID
    if [ "$ret" = "" ]; then
        exit 1
    fi
done
