#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p dash nix fswatch nodejs yajsv parallel findutils coreutils gnused avahi python39 python3Packages.pycryptodome jq yq bc
. ./logging
. ./profiling
set -eu

export PATH="$HOME/.local/nix-override:$PATH"
export PARALLEL_SHELL=dash
#export LOGGING_LEVEL=warn

#export HOMEKIT_SH_CACHE_TOML=true
export HOMEKIT_SH_CACHE_ACCESSORIES=true

rm -fR ./store/sessions/*
parallel -u ::: ./broadcast.sh ./monitor.sh ./poller.sh "./serve.sh $(cat ./config/port)"