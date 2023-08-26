#!/bin/bash

profiling="$1"

sort -k1 <(
    for f in /tmp/profiling."$profiling".*.log; do
        currentscript=$(basename "${f/.log/}" | cut -d . -f 4-)
        paste <(
            while read -r tim ;do
                [ -z "$last" ] && last=${tim//.} && first=${tim//.}
                crt=000000000$((${tim//.}-10#0$last))
                ctot=000000000$((${tim//.}-10#0$first))
                printf "%9.6f %9.6f %-25s\n" ${ctot:0:${#ctot}-9}.${ctot:${#ctot}-9} \
                                             ${crt:0:${#crt}-9}.${crt:${#crt}-9} \
                                             "$currentscript"
                last=${tim//.}
            done < "${f/.log/.tim}"
        ) "$f"
    done;
)