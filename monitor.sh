#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p dash fswatch gnused
. ./logging
. ./profiling
set -eu

while true
do
    ret="$(fswatch -1 ./accessories)"
    logger_info "./accessories/ was modified"
    if [ "$ret" = "" ]; then
        exit 1
    fi
    rm -R ./store/cache
    mkdir -p ./store/cache
    dash ./api/accessories.sh
    current="$(sed 's/c#=\([^ ]*\) .*/\1/' ./store/dns-txt)"
    newval="$((current+1))"
    logger_info "Updated configuration number $current -> $newval"
    sed -i "s/c#=[0-9]*/c#=$newval/" ./store/dns-txt
done
