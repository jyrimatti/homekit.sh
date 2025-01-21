#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-24.11-small -p nix dash yq jq ncurses
. ./prefs
. ./log/logging_no_exit_trap
. ./profiling
set -eu

logger_trace 'util/tomlq-cached.sh'

params="$1"
query="$2"
shift 2

logger_debug "Using tomlq for $*"
tomlq $params "$query" $*