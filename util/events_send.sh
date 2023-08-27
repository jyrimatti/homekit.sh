#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p dash jq ncurses
. ./logging
. ./profiling
set -eu

logger_trace 'util/events_send.sh'

session_store="./store/sessions/$REMOTE_ADDR:$REMOTE_PORT"

events=$(mktemp /tmp/homekit.sh_events_send.XXXXXX)
for f in "$session_store"/events/*.json; do
    if test -f "$f"; then
        cat "$f" >> "$events"
        rm "$f"
    fi
done

if test -s "$events"; then
    content=$(jq '.characteristics' "$events" | jq -cs 'add | {characteristics: .}')

    logger_info "Sending events $content"

    echo 'EVENT/1.0 200 OK'
    echo 'Content-Type: application/hap+json'
    echo "Content-Length: ${#content}"
    echo ''
    echo -n "$content"
fi