#!/bin/bash

if [ ! -e sdram.hex ]; then
    ln -sf ../../rom/tricktrp.rom rom.bin
    bin2hex <rom.bin >sdram.hex
fi

export MEM_CHECK_TIME=210_000_000
export CONVERT_OPTIONS="-resize 300%x300%"
export YM2203=1
export M6809=1

# Generic simulation script from JTFRAME
sim.sh -mist -sysname labrun  \
    -d JTFRAME_DWNLD_PROM_ONLY \
    -def ../../hdl/jtlabrun.def \
    -videow 280 -videoh 240 -d VIDEO_START=1 \
    $*
