#!/bin/bash

export JTROOT=$(pwd)
export JTFRAME=$JTROOT/modules/jtframe
source $JTFRAME/bin/setprj.sh $*

alias gfxinfo="$JTROOT/cc/gfxinfo"
alias jtcomsc="jtcore comsc"
alias jtcontra="jtcore contra"