#! /usr/bin/env nix-shell
#! nix-shell --pure -i dash -I channel:nixos-23.05-small -p dash nodejs nix jq which
. ./prefs
. ./log/logging
. ./profiling
set -eu

mkdir -p "$HOMEKIT_SH_STORE_DIR"
mkdir -p "$HOMEKIT_SH_CACHE_DIR"
mkdir -p "$HOMEKIT_SH_RUNTIME_DIR"
mkdir -p "$HOMEKIT_SH_ACCESSORIES_DIR"

if [ -n "${HOMEKIT_SH_NIX_OVERRIDE:-}" ]; then
    mkdir -p "$HOMEKIT_SH_STORE_DIR/nix-override"
    ln -fs "$(which dash)" "$HOMEKIT_SH_STORE_DIR/nix-override/nix-shell"
fi

mkdir -p "$HOMEKIT_SH_STORE_DIR/pairings"
mkdir -p "$HOMEKIT_SH_STORE_DIR/sent_events"
mkdir -p "$HOMEKIT_SH_RUNTIME_DIR/sessions"
