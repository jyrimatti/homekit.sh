#! /usr/bin/env nix-shell
#! nix-shell --pure -i dash -I channel:nixos-23.05-small -p dash nodejs nix jq which
. ./prefs
. ./logging
. ./profiling
set -eu

export LC_ALL=C # "fix" Nix Perl locale warnings

rm -fR ./store/*

mkdir -p "$HOMEKIT_SH_STORE_DIR"
mkdir -p "$HOMEKIT_SH_CACHE_DIR"
mkdir -p "$HOMEKIT_SH_RUNTIME_DIR"

if [ -n "${HOMEKIT_SH_NIX_OVERRIDE:-}" ]; then
    mkdir -p "$HOMEKIT_SH_STORE_DIR/nix-override"
    ln -fs "$(which dash)" "$HOMEKIT_SH_STORE_DIR/nix-override/nix-shell"
fi

mkdir -p "$HOMEKIT_SH_STORE_DIR/pairings"
mkdir -p "$HOMEKIT_SH_STORE_DIR/sent_events"
mkdir -p "$HOMEKIT_SH_RUNTIME_DIR/sessions"
echo "c#=1 id=$HOMEKIT_SH_USERNAME md=homekit.sh s#=1 sf=1 ci=2 pv=1.1 ff=0" > "$HOMEKIT_SH_STORE_DIR/dns-txt"

(cd pairing && npm install && npm run createSecrets)