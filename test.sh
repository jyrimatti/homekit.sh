#! /usr/bin/env nix-shell
#! nix-shell --pure -i dash -I channel:nixos-23.11-small -p dash nix shellspec which fswatch nodejs yajsv findutils coreutils gnused avahi python3Packages.pycryptodome python3Packages.pynacl python3Packages.tlv8 python3Packages.srp python3Packages.aioharmony yq htmlq bc jq websocat flock getoptions ncurses curl xxd "pkgs.callPackage ./wolfclu.nix {}"
. ./prelude
set -eu

prefix="${1:-}"

if [ -n "${HOMEKIT_SH_NIX_OVERRIDE:-}" ]; then
    mkdir -p "$HOMEKIT_SH_STORE_DIR/nix-override"
    ln -fs "$(which dash)" "$HOMEKIT_SH_STORE_DIR/nix-override/nix-shell"
    export PATH="$HOMEKIT_SH_STORE_DIR/nix-override:$PATH"
fi

shellspec --shell dash --fail-fast --format documentation spec/$prefix*