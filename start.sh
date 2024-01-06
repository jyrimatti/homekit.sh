#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash nix which fswatch nodejs yajsv parallel findutils coreutils gnused avahi python3Packages.pycryptodome python3Packages.pynacl yq htmlq bc jq websocat flock getoptions ncurses curl sqlite "pkgs.callPackage ./modbus_cli.nix {}" "pkgs.callPackage ./wolfclu.nix {}"
. ./prefs
. ./log/logging
. ./profiling
set -eu

startprocesses="${1:-startprocesses}"

export LC_ALL=C # "fix" Nix Perl locale warnings

dash ./initdirs.sh

if [ -n "${HOMEKIT_SH_NIX_OVERRIDE:-}" ]; then
    export PATH="$HOMEKIT_SH_STORE_DIR/nix-override:$PATH"
fi

rm -fR "$HOMEKIT_SH_RUNTIME_DIR/sessions/*"

if [ "$startprocesses" = 'startprocesses' ]; then
    logger_info "Starting Homekit.sh with ENV:"
    logger_info "$(env)"
    parallel -u ::: ./broadcast.sh ./monitor.sh ./poller.sh "./serve.sh $HOMEKIT_SH_PORT"
fi
