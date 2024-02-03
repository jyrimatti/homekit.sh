#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash fswatch avahi
. ./prelude
set -eu

while true
do
    if command -v dns-sd >/dev/null; then
        logger_info "Broadcasting with dns-sd"
        dns-sd -R homekit.sh _hap._tcp . "$HOMEKIT_SH_PORT" $(cat "$HOMEKIT_SH_STORE_DIR/dns-txt") &
    else
        logger_info "Broadcasting with avahi"
        avahi-publish -s homekit.sh _hap._tcp "$HOMEKIT_SH_PORT" $(cat "$HOMEKIT_SH_STORE_DIR/dns-txt") &
    fi
    DNSSD_PID=$!

    trap 'kill $DNSSD_PID' EXIT

    ret="$(fswatch -1 -m poll_monitor "$HOMEKIT_SH_STORE_DIR/dns-txt")"
    logger_info "dns-txt was modified"
    kill $DNSSD_PID
    if [ "$ret" = "" ]; then
        logger_info "exiting broadcast.sh..."
        exit 1
    fi
done
