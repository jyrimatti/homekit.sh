#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p dash fswatch gnused
. ./logging
. ./profiling
set -eu

while true
do
    ret="$(fswatch -1 --insensitive --exclude '.*' --include '.*[.]toml$' ./accessories)"
    logger_info "Some .toml file under ./accessories was modified"
    if [ "$ret" = "" ]; then
        exit 1
    fi
    
    rm -R "$HOMEKIT_SH_CACHE_DIR"
    
    . ./config/caching
    dash ./util/cache_toml.sh

    current="$(sed 's/c#=\([^ ]*\) .*/\1/' ./store/dns-txt)"
    newval="$((current+1))"
    logger_info "Updated configuration number $current -> $newval"
    sed -i "s/c#=[0-9]*/c#=$newval/" ./store/dns-txt
done
