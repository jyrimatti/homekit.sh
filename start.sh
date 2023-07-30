#! /usr/bin/env nix-shell
#! nix-shell -i bash -I channel:nixos-23.05-small -p bash nix fswatch nodejs yajsv parallel findutils coreutils gnused avahi python39 python3Packages.pycryptodome jq yq 
set -euo pipefail

export PATH="$HOME/.local/nix-override:$PATH"

rm -fR ./store/sessions/*
parallel -u ::: ./broadcast.sh ./poller.sh "./serve.sh $(cat ./config/port)"