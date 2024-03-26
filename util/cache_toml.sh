#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash coreutils ncurses yq yajsv sqlite
. ./prelude

set -eu

logger_trace 'util/cache_toml.sh'

dash ./util/cache_env.sh
dash ./util/cache_disk.sh
dash ./util/cache_fs_structure.sh
dash ./util/cache_fs_aid.sh
dash ./util/cache_accessories.sh
dash ./util/cache_sqlite.sh

logger_trace 'Finished util/cache_toml.sh'