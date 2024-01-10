#!/usr/bin/env dash

urldecode() {
    echo "$1" | sed 'y/+/ /; s/%/\\x/g'
}

read_querystring() {
    q="$(urldecode "$QUERY_STRING")"
    saveIFS="$IFS"
    IFS='&'
    for f in $q; do
        value="${f##*=}"
        key="${f%%=*}"
        eval "qs_$key='$value'"
    done
    IFS="$saveIFS"
}

read_querystring

read_binary() {
    if [ "${CONTENT_LENGTH:-}" = "" ]; then
        cat
    else
        echo "reading $CONTENT_LENGTH bytes..." >&2
        dd ibs=1 count="$CONTENT_LENGTH" 2> /dev/null
    fi
}