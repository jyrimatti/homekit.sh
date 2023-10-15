#! /usr/bin/env nix-shell
#! nix-shell --pure -i dash -I channel:nixos-23.05-small -p dash nodejs nix jq which
. ./prefs
. ./log/logging
. ./profiling
set -eu

export LC_ALL=C # "fix" Nix Perl locale warnings

rm -fR "$HOMEKIT_SH_STORE_DIR"
rm -fR "$HOMEKIT_SH_RUNTIME_DIR"
rm -fR "$HOMEKIT_SH_CACHE_DIR"

dash ./initdirs.sh

(cd pairing && npm install && npm run createSecrets)