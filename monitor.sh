#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash fswatch gnused
. ./prefs
. ./log/logging
. ./profiling
set -eu

logger_info "Monitoring for .toml files under $HOMEKIT_SH_ACCESSORIES_DIR..."
while true
do
    ret="$(fswatch -1 --event Updated --insensitive --exclude '.*' --include '.*[.]toml$' "$HOMEKIT_SH_ACCESSORIES_DIR"/* "$HOMEKIT_SH_ACCESSORIES_DIR"/*/*)"
    logger_info "Some .toml file under $HOMEKIT_SH_ACCESSORIES_DIR was modified: $ret"
    if [ "$ret" = "" ]; then
        exit 1
    fi
    
    rm -R "$HOMEKIT_SH_CACHE_DIR"
    
    . ./prefs
    ./util/cache_toml.sh

    current="$(sed 's/c#=\([^ ]*\) .*/\1/' "$HOMEKIT_SH_STORE_DIR/dns-txt")"
    newval="$((current+1))"
    logger_info "Updated configuration number $current -> $newval"
    sed -i "s/c#=[0-9]*/c#=$newval/" "$HOMEKIT_SH_STORE_DIR/dns-txt"
done
