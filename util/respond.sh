#! /usr/bin/env nix-shell
#! nix-shell -i dash -I channel:nixos-23.05-small -p dash
. ./logging
. ./profiling
set -eu

logger_trace 'util/respond.sh'

status="$1"
content="${2:-___no_content___}"

contentType='Content-Type: application/hap+json'

if [ "${REQUEST_TYPE:-}" = 'encrypted' ]; then
    logger_debug 'Encrypted request -> outputtin HTTP status header'
    if [ "$status" = 200 ]; then
        echo 'HTTP/1.1 200 OK'
    elif [ "$status" = 204 ]; then
        echo 'HTTP/1.1 204 No Content'
    elif [ "$status" = 207 ]; then
        echo 'HTTP/1.1 207 Multi-Status'
    elif [ "$status" = 400 ]; then
        echo 'HTTP/1.1 400 Bad Request'
    fi
fi

logger_debug "Responding with ${REQUEST_TYPE:-?} $status"

if [ "$content" = '___no_content___' ]; then
    echo ''
else
    echo "$contentType"
    echo "Content-Length: $(echo -n "$content" | wc -c)"
    echo ''
    echo -n "$content"
fi