#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.11-small -p dash jq ncurses
. ./prefs
. ./log/logging
. ./profiling
set -eu

logger_trace 'util/events_send.sh'

session_store="$HOMEKIT_SH_RUNTIME_DIR/sessions/$REMOTE_ADDR:$REMOTE_PORT"

if [ -n "$(ls -A "$session_store"/events 2>/dev/null)" ]; then
    events="$(mktemp "$HOMEKIT_SH_RUNTIME_DIR/homekit.sh_events_send.XXXXXX")"
    sent="$(date -u +%Y-%m-%dT%H:%M:%S)"
    for f in "$session_store"/events/*.json; do
        if test -f "$f"; then
            cat "$f" >> "$events"
            mv "$f" "$HOMEKIT_SH_STORE_DIR/sent_events/$(basename "$f")_$sent"
        fi
    done

    if test -s "$events"; then
        content="$(jq '.characteristics' "$events" | jq -jcs 'add | {characteristics: .}')"

        logger_info "Sending events $content"

        printf "EVENT/1.0 200 OK\r\n"
        printf "Content-Type: application/hap+json\r\n"
        printf "Connection: keep-alive\r\n"
        printf "Content-Length: %i\r\n" "${#content}"
        printf "\r\n"
        printf "%s" "$content"
    fi
    rm "$events"
fi