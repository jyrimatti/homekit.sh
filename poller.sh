#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-24.11-small -p dash nix coreutils findutils gnugrep
. ./prelude
set -eu

if [ -n "${HOMEKIT_SH_NIX_OVERRIDE:-}" ]; then
    export PATH="$HOMEKIT_SH_STORE_DIR/nix-override:$PATH"
fi

while true
do
    logger_debug "Polling subscriptions"
    find "$HOMEKIT_SH_RUNTIME_DIR/sessions" -mindepth 3 -maxdepth 3 -type f |\
        grep subscriptions |\
        sed 's/.*homekit.sh\///' |\
        cut --output-delimiter ' ' -d / -f 2,4  |\
        xargs -r -L1 dash ./util/poll.sh |\
        "./bin/rust-parallel-$(uname)" --jobs "${PROFILING:-$HOMEKIT_SH_PARALLELISM}" || true
    
    sleep 1
done
