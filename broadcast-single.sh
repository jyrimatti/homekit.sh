#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash fswatch avahi
. ./prelude
set -eu

port="$1"
bridge="${2:-}"

if [ "$bridge" != "" ]; then
    bridge="/$bridge"
fi

while true
do
    if command -v dns-sd >/dev/null; then
        logger_info "Broadcasting with dns-sd, bridge: ${bridge:-homekit.sh}"
        dns-sd -R "homekit.sh$bridge" _hap._tcp . "$port" $(cat "${HOMEKIT_SH_STORE_DIR}${bridge}/dns-txt") &
    else
        logger_info "Broadcasting with avahi, bridge: ${bridge:-homekit.sh}"
        avahi-publish -s "homekit.sh$bridge" _hap._tcp "$port" $(cat "$HOMEKIT_SH_STORE_DIR${bridge}/dns-txt") &
    fi
    DNSSD_PID=$!

    trap 'kill $DNSSD_PID' EXIT

    ret="$(fswatch -1 -m poll_monitor "$HOMEKIT_SH_STORE_DIR${bridge}/dns-txt")"
    logger_info "dns-txt was modified for bridge: ${bridge:-homekit.sh}"
    kill $DNSSD_PID
    if [ "$ret" = "" ]; then
        logger_info "exiting broadcast.sh for bridge: ${bridge:-homekit.sh}..."
        exit 1
    fi
done
