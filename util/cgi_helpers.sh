#!/bin/bash
set -euo pipefail

urldecode() {
    local i="${*//+/ }"
    echo "${i//%/\\x}"
}

read_querystring() {
    q="$(urldecode "$QUERY_STRING")"
    saveIFS=$IFS
    IFS='=&'
    parm=($q)
    IFS=$saveIFS
    for ((i=0; i<${#parm[@]}; i+=2))
    do
        query_params[${parm[i]}]=${parm[i+1]}
    done
}

declare -A query_params
export query_params
read_querystring