#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash nix "pkgs.callPackage ../wolfclu.nix {}"
set -eux

inkey="$1"
in="$2"
out="$3"

wolfssl -ed25519 -sign -inkey "$inkey" -in "$in" -out "$out"
