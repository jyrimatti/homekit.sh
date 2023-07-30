#! /usr/bin/env nix-shell
#! nix-shell -i bash -I channel:nixos-23.05-small -p nix shellspec jq yq nodejs yajsv parallel coreutils
set -eu

prefix=${1:-}

export PATH="~/.local/nix-override:$PATH"

shellspec --format documentation spec/$prefix*