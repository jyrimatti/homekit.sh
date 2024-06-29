#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash coreutils ncurses yq yajsv jq
. ./prelude

set -eu

logger_trace 'util/cache_toml.sh'

dash ./util/cache_fs_structure.sh
dash ./util/cache_fs_aid.sh
dash ./util/cache_fs_bridge.sh
dash ./util/cache_accessories.sh

logger_trace 'Finished util/cache_toml.sh'