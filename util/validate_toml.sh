#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-24.11-small -p dash gnused yq yajsv ncurses
. ./prelude

set -eu

logger_trace 'util/validate_toml.sh'

tomlfile="$1"

case "$tomlfile" in
  *'accessories/'*)
    mkdir -p "$HOMEKIT_SH_RUNTIME_DIR"
    tmpfile="$(mktemp "$HOMEKIT_SH_RUNTIME_DIR/homekit.sh_validate_toml.XXXXXX.json")"
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
