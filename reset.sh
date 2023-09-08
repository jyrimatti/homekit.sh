#! /usr/bin/env nix-shell
#! nix-shell --pure -i dash -I channel:nixos-23.05-small -p dash nodejs nix
. ./logging
. ./profiling
set -eu

rm -fR ./store/*

echo "c#=1 id=$(cat config/username) md=homekit.sh s#=1 sf=1 ci=2 pv=1.1 ff=0" > store/dns-txt
mkdir -p ./store/pairings
mkdir -p ./store/sessions
mkdir -p ./store/sent_events
mkdir -p ./store/cache/accessories
mkdir -p ./store/cache/characteristics
mkdir -p ./store/cache/config
mkdir -p ./store/cache/values

. ./preferences.sh

./util/cache_toml.sh

(cd pairing && npm run createSecrets)