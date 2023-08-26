#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p dash
. ./logging
. ./profiling

set -eu

# Retrieve cached toml file from environment, or empty string if not found

logger_trace 'util/cache_get.sh'

tomlfile="$1"

envVarName="HOMEKIT_SH_$(./util/cache_mkkey.sh "$tomlfile")"
eval "found=\${$envVarName+x}"
if [ -z "$found" ]; then
    exit 1
fi

eval "echo \"\${$envVarName}\""
