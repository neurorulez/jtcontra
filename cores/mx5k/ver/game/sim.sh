#!/bin/bash

AUXTMP=/tmp/$RANDOM$RANDOM
jtcfgstr -target=mist -output=bash -parse ../../hdl/jtmx5k.def |grep _START > $AUXTMP
source $AUXTMP

jtsim_sdram

export M6809=1

# Generic simulation script from JTFRAME
jtsim -mist -sysname mx5k  \
    -d JT51_NODEBUG  \
    -videow 280 -videoh 224 \
    $*
