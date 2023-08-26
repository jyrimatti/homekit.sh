#! /usr/bin/env nix-shell
#! nix-shell --pure -i dash -I channel:nixos-23.05-small -p dash nix coreutils findutils gnugrep parallel
. ./logging
. ./profiling
set -eu

while true
do
    logger_debug "Polling subscriptions"
    find ./store/sessions -mindepth 3 -maxdepth 3 -type f |\
        grep subscriptions |\
        cut -d / -f 4,6 |\
        tr '/' ' ' |\
        xargs -r -L1 ./util/poll.sh |\
        parallel -k --jobs 0${PROFILING:+1} || true
    
    sleep 1
done
