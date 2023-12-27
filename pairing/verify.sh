#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash nix "pkgs.callPackage ../wolfclu.nix {}"
set -eu

inkey="$1"
in="$2"
sigfile="$3"

wolfssl -ed25519 -verify -inkey "$inkey" -in "$in" -sigfile "$sigfile" -pubin
