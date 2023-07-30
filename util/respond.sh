#! /usr/bin/env nix-shell
#! nix-shell --pure -i bash -I channel:nixos-23.05-small -p bash
set -euo pipefail
PS4='+ $(date "+%T.%3N ($LINENO) ")'

status=$1
content=${2:-___no_content___}

contentType='Content-Type: application/hap+json'

if [ "${REQUEST_TYPE:-}" == "encrypted" ]; then
    if [ "$status" = 200 ]; then
        echo 'HTTP/1.1 200 OK'
    elif [ "$status" = 204 ]; then
        echo 'HTTP/1.1 204 No Content'
    elif [ "$status" = 207 ]; then
        echo 'HTTP/1.1 207 Multi-Status'
    elif [ "$status" = 400 ]; then
        echo 'HTTP/1.1 400 Bad Request'
    fi
fi;

echo "Responding with $status: $content" >&2

if [ "$content" = '___no_content___' ]; then
    echo ''
else
    echo "$contentType"
    echo "Content-Length: $(echo "$content" | wc -c)"
    echo ''
    echo "$content"
fi