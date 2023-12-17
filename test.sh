#! /usr/bin/env nix-shell
#! nix-shell --pure -i dash -I channel:nixos-23.11-small -p dash nix which shellspec yq nodejs yajsv parallel coreutils bc ncurses sqlite jq "pkgs.callPackage ./modbus_cli.nix {}"
. ./prefs
. ./log/logging
. ./profiling
set -eu

prefix="${1:-}"

if [ -n "${HOMEKIT_SH_NIX_OVERRIDE:-}" ]; then
    mkdir -p "$HOMEKIT_SH_STORE_DIR/nix-override"
    ln -fs "$(which dash)" "$HOMEKIT_SH_STORE_DIR/nix-override/nix-shell"
    export PATH="$HOMEKIT_SH_STORE_DIR/nix-override:$PATH"
fi

shellspec --shell dash --fail-fast --format documentation spec/$prefix*