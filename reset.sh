#! /usr/bin/env nix-shell
#! nix-shell --pure -i dash -I channel:nixos-23.05-small -p dash nodejs nix jq which
. ./logging
. ./profiling
set -eu

export LC_ALL=C # "fix" Nix Perl locale warnings

rm -fR ./store/*

. ./config/caching
mkdir "$HOMEKIT_SH_CACHE_DIR"

if [ -n "${HOMEKIT_SH_NIX_OVERRIDE:-}" ]; then
    mkdir -p ./store/nix-override
    ln -fs "$(which dash)" ./store/nix-override/nix-shell
fi

mkdir -p ./store/pairings
mkdir -p ./store/sessions
mkdir -p ./store/sent_events
echo "c#=1 id=$(grep -v '^#' ./config/username) md=homekit.sh s#=1 sf=1 ci=2 pv=1.1 ff=0" > ./store/dns-txt

(cd pairing && npm install && npm run createSecrets)