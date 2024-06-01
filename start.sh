#! /usr/bin/env nix-shell
#! nix-shell -I channel:nixos-23.11-small -p coreutils findutils gnused bc xxd jq dash nix which fswatch nodejs yajsv avahi yq htmlq netcat websocat flock getoptions ncurses curl python3Packages.pycryptodome python3Packages.pynacl python3Packages.tlv8 python3Packages.srp python3Packages.aioharmony "pkgs.callPackage ./wolfclu.nix {}"
#! nix-shell -i dash
. ./prelude
set -eu

NIXPKGS_ALLOW_UNFREE=1 nix-shell -p ookla-speedtest --run 'echo '''

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

    dash ./util/bridges.sh \
        | while read -r port bridge username; do {
            HOMEKIT_SH_BRIDGE="$bridge" HOMEKIT_SH_USERNAME="${username:-$HOMEKIT_SH_USERNAME}" ./serve.sh "${port:-$HOMEKIT_SH_PORT}" &
          } done
    
    wait
fi
