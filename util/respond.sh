#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-24.11-small -p dash ncurses
. ./prelude
set -eu

logger_trace 'util/respond.sh'

status="$1"
content="${2:-}"
contentType="${3:-application/hap+json}"
contentLength="${4:-}"

if [ "$contentLength" = "" ]; then
    contentLength="${#content}"
fi

contentType="Content-Type: $contentType"
connection='Connection: keep-alive'

if [ "${REQUEST_TYPE:-}" = 'encrypted' ]; then
    logger_debug "Encrypted request -> outputtin HTTP status header $status"
    if [ "$status" = 200 ]; then
        printf "HTTP/1.1 200 OK\r\n"
    elif [ "$status" = 204 ]; then
        printf "HTTP/1.1 204 No Content\r\n"
    elif [ "$status" = 207 ]; then
        printf "HTTP/1.1 207 Multi-Status\r\n"
    elif [ "$status" = 400 ]; then
        printf "HTTP/1.1 400 Bad Request\r\n"
    fi
    printf "%s\r\n" "$connection"
fi

if [ -z "${2+x}" ]; then
    logger_debug "Responding with ${REQUEST_TYPE:-?} $status, $contentType and empty body"
    printf "\r\n"
else

    logger_debug "Responding with ${REQUEST_TYPE:-?} $status, $contentType and length ${contentLength}, content: $content"
    printf "%s\r\n" "$contentType"
    printf "Content-Length: %i\r\n" "${contentLength}"
    printf "\r\n"
    printf "%s" "$content"
fi