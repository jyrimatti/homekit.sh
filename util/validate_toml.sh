#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p dash gnused yq yajsv ncurses
. ./logging
. ./profiling

set -eu

logger_trace 'util/validate_toml.sh'

tomlfile="$1"

case "$tomlfile" in
  *'accessories/'*)
    tmpfile="$(mktemp "$HOMEKIT_SH_CACHE_DIR/homekit.sh_validate_toml.XXXXXX.json")"
    tomlq -c < "$tomlfile" > "$tmpfile"

    logger_debug "Validating toml file $tomlfile"
    yajsv -q -s ./accessory.schema.json "$tmpfile" | sed "s#$tmpfile#$tomlfile#" >&2

    cat "$tmpfile"
    rm "$tmpfile"
    ;;
  *)
    tomlq -cj 'to_entries[] | {(.key):.value}' "$tomlfile"
    ;;
esac
