#!/bin/sh

# just in case it cannot detect it correctly
export PARALLEL_SHELL="dash"

# caching
export HOMEKIT_SH_CACHE_SERVICES=true
#export HOMEKIT_SH_CACHE_VALUES=5
export HOMEKIT_SH_CACHE_TOML_DISK=true
#export HOMEKIT_SH_CACHE_TOML_ENV=true
#export HOMEKIT_SH_CACHE_ACCESSORIES=true