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