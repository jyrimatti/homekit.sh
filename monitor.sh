#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash fswatch gnused yq
. ./prelude
set -eu

logger_info "Monitoring for .toml files under $HOMEKIT_SH_ACCESSORIES_DIR..."
while true
do
    ret="$(fswatch -1 --event Updated --insensitive --exclude '.*' --include '.*[.]toml$' "$HOMEKIT_SH_ACCESSORIES_DIR"/* "$HOMEKIT_SH_ACCESSORIES_DIR"/*/*)"
    logger_info "Some .toml file under $HOMEKIT_SH_ACCESSORIES_DIR was modified: $ret"
    if [ "$ret" = "" ]; then
        exit 1
    fi
    
    . ./prefs
    . ./util/cache_toml.sh

    dash ./util/bridges.sh \
        | while read -r port bridge username; do {
            if [ "$bridge" != "" ]; then
                bridge="/$bridge"
            fi
            current="$(sed 's/c#=\([^ ]*\) .*/\1/' "${HOMEKIT_SH_STORE_DIR}${bridge}/dns-txt")"
            newval="$((current+1))"
            logger_info "Updated configuration number $current -> $newval for bridge: ${bridge:-homekit.sh}"
            sed -i "s/c#=[0-9]*/c#=$newval/" "$HOMEKIT_SH_STORE_DIR${bridge}/dns-txt"
          } done
done
