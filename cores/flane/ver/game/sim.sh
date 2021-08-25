#!/bin/bash

AUXTMP=/tmp/$RANDOM$RANDOM
jtcfgstr -target=mist -output=bash -parse ../../hdl/jtflane.def |grep _START > $AUXTMP
source $AUXTMP

jtsim_sdram

export M6809=1

# Generic simulation script from JTFRAME
jtsim -mist -sysname flane  \
    -d JT51_NODEBUG  \
    -videow 280 -videoh 224 \
    $*
