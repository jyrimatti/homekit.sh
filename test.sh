#! /usr/bin/env nix-shell
#! nix-shell --pure -i dash -I channel:nixos-23.05-small -p dash nix shellspec jq yq nodejs yajsv parallel coreutils
. ./logging
. ./profiling
set -eu

prefix="${1:-}"

shellspec --shell dash --fail-fast --format documentation -e PATH="~/.local/nix-override:$PATH" spec/$prefix*