#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-24.11-small -p nix dash jq coreutils findutils ncurses
. ./prelude
set -eu

logger_trace 'util/generate_service.sh'

withvalue="$1"
aid="$2"
services_of_same_type="$3"

echo "$services_of_same_type"\
 | jq -c '.[]'\
 | nl\
 | "./bin/rust-parallel-$(uname)" -r '\s*([0-9]+)\s*(.*)' --jobs "${PROFILING:-$HOMEKIT_SH_PARALLELISM}" -s --shell-path dash "echo '{2}' | dash ./util/generate_service_internal.sh $withvalue $aid {1}"
