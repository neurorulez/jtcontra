#!/bin/bash

ROMFILE=$ROM/tricktrp.rom

if [ ! -e $ROMFILE ]; then
    echo "Missing $ROMFILE"
    exit 1
fi

ln -sf $ROMFILE rom.bin
ln -sf $ROMFILE sdram_bank0.bin

export MEM_CHECK_TIME=210_000_000
export CONVERT_OPTIONS="-resize 300%x300%"
export YM2203=1
export M6809=1

# JTFRAME_SIM_DIPS="~'h8000" --> Enables demo sounds

# Generic simulation script from JTFRAME
jtsim -mist -sysname labrun  \
    -d JTFRAME_DWNLD_PROM_ONLY \
    -def ../../hdl/jtlabrun.def \
    -videow 280 -videoh 240 \
    -d JTFRAME_SIM_DIPS="~'h8000" \
    $*
