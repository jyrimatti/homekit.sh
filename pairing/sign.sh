#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash nix "pkgs.callPackage ../wolfclu.nix {}"
set -eu

inkey="$1" # filename for key

# reads input data from stdin
# writes signature to stdout, encoded as hex

wolfssl -ed25519 -sign -inkey "$inkey" -in "-" | od -A n -v -t x1 | tr -d ' \n'
