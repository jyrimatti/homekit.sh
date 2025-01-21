#! /usr/bin/env nix-shell
#! nix-shell --pure --keep LD_LIBRARY_PATH -i dash -I channel:nixos-24.11-small -p dash nix ncurses
. ./prelude
set -eu

rm -fR "${HOMEKIT_SH_CACHE_DIR:?}"/*
rm -fR "${HOMEKIT_SH_RUNTIME_DIR:?}"/sessions/*/cache