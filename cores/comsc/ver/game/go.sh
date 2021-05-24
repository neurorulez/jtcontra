#!/bin/bash

# if [ ! -e sdram_bank0.hex ]; then
#     if [ ! -e rom.bin ]; then
#         ln -sf $JTROOT/rom/comsc.rom rom.bin
#     fi
#     bin2hex <rom.bin >sdram_bank0.hex
# fi

ln -sf $JTROOT/rom/comsc.rom sdram_bank0.bin

export MEM_CHECK_TIME=210_000_000
export CONVERT_OPTIONS="-resize 300%x300%"
export M6809=1
export UDP7759=1

# Generic simulation script from JTFRAME
jtsim -mist -sysname contra  \
    -d JTFRAME_DWNLD_PROM_ONLY \
    -def ../../hdl/jtcomsc.def \
    -videow 280 -videoh 224 \
    $*
