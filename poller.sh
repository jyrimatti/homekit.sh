#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash nix coreutils findutils gnugrep
. ./prefs
. ./log/logging
. ./profiling
set -eu

if [ -n "${HOMEKIT_SH_NIX_OVERRIDE:-}" ]; then
    export PATH="$HOMEKIT_SH_STORE_DIR/nix-override:$PATH"
fi

while true
do
    logger_debug "Polling subscriptions"
    find "$HOMEKIT_SH_RUNTIME_DIR/sessions" -mindepth 3 -maxdepth 3 -type f |\
        grep subscriptions |\
        cut -d / -f 4,6 |\
        tr '/' ' ' |\
        xargs -r -L1 dash ./util/poll.sh |\
        "./bin/rust-parallel-$(uname)" --jobs "${PROFILING:-$HOMEKIT_SH_PARALLELISM}" || true
    
    sleep 1
done
