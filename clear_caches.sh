#! /usr/bin/env nix-shell
#! nix-shell --pure -i dash -I channel:nixos-23.11-small -p dash nix ncurses
. ./prelude
set -eu

rm -R "${HOMEKIT_SH_CACHE_DIR:?}"/*
rm -R "${HOMEKIT_SH_RUNTIME_DIR:?}"/sessions/*/cache