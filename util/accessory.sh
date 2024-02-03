#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p nix dash findutils ncurses
. ./prelude

set -eu

logger_trace 'util/accessory.sh'

toml="$1"

aid="$(dash ./util/aid.sh "$toml")"
dash ./util/services_grouped_by_type.sh "$toml" \
  | ./bin/rust-parallel-"$(uname)" --shell-path dash -r '.*' --jobs "${PROFILING:-$HOMEKIT_SH_PARALLELISM}" dash ./util/generate_service.sh 1 "$aid" "{0}" \
  | jq -cs "{ aid: $aid, services: map({type, iid, characteristics}) }"
