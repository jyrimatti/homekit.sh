#! /usr/bin/env nix-shell
#! nix-shell --pure --keep REMOTE_ADDR --keep REMOTE_PORT -i bash -I channel:nixos-23.05-small -p jq
set -euo pipefail
PS4='+ $(date "+%T.%3N ($LINENO) ")'

session_store="./store/sessions/$REMOTE_ADDR:$REMOTE_PORT"

events=$(mktemp /tmp/homekit.sh_events_send.XXXXXX)
for f in "$session_store"/events/*.json; do
    if test -f "$f"; then
        cat "$f" >> "$events"
        rm "$f"
    fi
done

if test -s "$events"; then
    content=$(cat "$events" | jq '.characteristics' | jq -s 'add | {characteristics: .}')

    echo "Sending events $content" >&2

    echo 'EVENT/1.0 200 OK'
    echo 'Content-Type: application/hap+json'
    echo "Content-Length: $(echo "$content" | wc -c)"
    echo ''
    echo "$content"
fi