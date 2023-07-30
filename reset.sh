#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -I channel:nixos-23.05-small -p nodejs
set -eu

rm -fR store/*

echo "c#=1 id=$(cat config/username) md=homekit.sh s#=1 sf=1 ci=2 pv=1.1 ff=0" > store/dns-txt
mkdir -p store/pairings
mkdir -p store/sessions

(cd pairing && npm run createSecrets)