#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-24.11-small -p dash nix coreutils ncurses "pkgs.callPackage ./wolfclu.nix {}"
. ./prelude
set -eu

logger_trace 'pairing/generate_random_bytes.sh'

bytes="$1"

wolfssl rand "$bytes" | ./util/bin2hex.sh