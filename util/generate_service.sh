#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p nix dash jq coreutils findutils parallel
. ./logging
. ./profiling
set -eu

logger_trace 'util/generate_service.sh'

services_of_same_type="$1"

echo "$services_of_same_type" | jq -c '.[]' |\
                                parallel --jobs 0${PROFILING:+1} "echo {} | ./util/generate_service_internal.sh {#}"
