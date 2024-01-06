#! /usr/bin/env nix-shell
#! nix-shell --pure -i dash -I channel:nixos-23.11-small -p dash nix jq ncurses which "pkgs.callPackage ./wolfclu.nix {}"
. ./prefs
. ./log/logging
. ./profiling
set -eu

export LC_ALL=C # "fix" Nix Perl locale warnings

rm -fR "$HOMEKIT_SH_STORE_DIR"
rm -fR "$HOMEKIT_SH_RUNTIME_DIR"
rm -fR "$HOMEKIT_SH_CACHE_DIR"

dash ./initdirs.sh

./pairing/generate_sign_keypair.sh "$HOMEKIT_SH_STORE_DIR/AccessoryLTPK" "$HOMEKIT_SH_STORE_DIR/AccessoryLTSK"
