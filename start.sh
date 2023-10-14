#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p dash nix fswatch nodejs yajsv parallel findutils coreutils gnused avahi python39 python3Packages.pycryptodome yq htmlq bc websocat flock getoptions ncurses curl sqlite "pkgs.callPackage ./jq-1.7.nix {}" "pkgs.callPackage ./modbus_cli.nix {}"
. ./prefs
. ./logging
. ./profiling
set -eu

# nix-env -iE "let pkgs = import <nixpkgs> {}; in jq: (with pkgs; import ./jq-1.7.nix { inherit lib fetchurl stdenv autoreconfHook oniguruma; })"
# nix-env -iE "let pkgs = import <nixpkgs> {}; in jq: (with pkgs; import ./accessories/stiebel/modbus_cli.nix { inherit python3Packages; })"


if [ -n "${HOMEKIT_SH_NIX_OVERRIDE:-}" ]; then
    mkdir -p ./store/nix-override
    ln -fs "$(which dash)" ./store/nix-override/nix-shell
    export PATH="$(pwd)/store/nix-override:$PATH"
fi

export LC_ALL=C # "fix" Nix Perl locale warnings

rm -fR ./store/sessions/*
parallel -u ::: ./broadcast.sh ./monitor.sh ./poller.sh "./serve.sh $(grep -v '^#' ./config/port)"