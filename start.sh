#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p dash nix which fswatch nodejs yajsv parallel findutils coreutils gnused avahi python39 python3Packages.pycryptodome yq htmlq bc websocat flock getoptions ncurses curl sqlite "pkgs.callPackage ./jq-1.7.nix {}" "pkgs.callPackage ./modbus_cli.nix {}"
. ./prefs
. ./log/logging
. ./profiling
set -eu

startprocesses="${1:-startprocesses}"

# nix-env -iE "let pkgs = import <nixpkgs> {}; in jq: (with pkgs; import ./jq-1.7.nix { inherit lib fetchurl stdenv autoreconfHook oniguruma; })"
# nix-env -iE "let pkgs = import <nixpkgs> {}; in jq: (with pkgs; import ./modbus_cli.nix { inherit python3Packages; })"

export LC_ALL=C # "fix" Nix Perl locale warnings

dash ./initdirs.sh

if [ -n "${HOMEKIT_SH_NIX_OVERRIDE:-}" ]; then
    export PATH="$HOMEKIT_SH_STORE_DIR/nix-override:$PATH"
fi

rm -fR "$HOMEKIT_SH_RUNTIME_DIR/sessions/*"
mkdir -p "$HOMEKIT_SH_RUNTIME_DIR/sessions"

if [ "$startprocesses" = 'startprocesses' ]; then
    logger_info "Starting Homekit.sh with ENV:"
    logger_info "$(env)"
    parallel -u ::: ./broadcast.sh ./monitor.sh ./poller.sh "./serve.sh $HOMEKIT_SH_PORT"
fi
