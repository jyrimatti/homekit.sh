#! /usr/bin/env nix-shell
#! nix-shell --pure --keep LD_LIBRARY_PATH -i dash -I channel:nixos-24.11-small -p nix dash yq jq ncurses which "pkgs.callPackage ./wolfclu.nix {}"
. ./prelude
set -eu

export LC_ALL=C # "fix" Nix Perl locale warnings

rm -fR "$HOMEKIT_SH_STORE_DIR"
rm -fR "$HOMEKIT_SH_RUNTIME_DIR"

dash ./clear_caches.sh

dash ./initdirs.sh

dash ./pairing/generate_sign_keypair.sh "$HOMEKIT_SH_STORE_DIR/AccessoryLTPK" "$HOMEKIT_SH_STORE_DIR/AccessoryLTSK"
