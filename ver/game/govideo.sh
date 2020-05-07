#!/bin/bash

OTHER=

while [ $# -gt 0 ]; do
    case $1 in
        -s)
            shift
            if [ ! -d scene${1} ]; then
                echo "Cannot find scene #" $1
                exit 1
            fi
            cp scene${1}/* .;;
        *) OTHER="$OTHER $1";;
    esac
    shift
done

go.sh -d GFX_ONLY -d NOSOUND -video 2 -deep -d VIDEO_START=1 $OTHER