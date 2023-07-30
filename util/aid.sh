#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -I channel:nixos-23.05-small -p nix yq
set -euo pipefail
PS4='+ $(date "+%T.%3N ($LINENO) ")'

# use Accessory Instance ID from toml file if provided, or hash the file path

tomlfile=$1

tomlq -e '.aid // empty' "$tomlfile" || echo "$tomlfile" | ./util/hash.sh