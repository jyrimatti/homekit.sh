#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p dash nix fswatch nodejs yajsv parallel findutils coreutils gnused avahi python39 python3Packages.pycryptodome jq yq htmlq bc websocat flock getoptions ncurses curl "pkgs.callPackage ./accessories/stiebel/modbus_cli.nix {}"
. ./logging
. ./profiling
set -eu

export PATH="$HOME/.local/nix-override:$PATH"
export LC_ALL=C # "fix" Nix Perl locale warnings

rm -fR ./store/sessions/*
parallel -u ::: ./broadcast.sh ./monitor.sh ./poller.sh "./serve.sh $(cat ./config/port)"