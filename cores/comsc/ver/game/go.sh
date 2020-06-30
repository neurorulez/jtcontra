#!/bin/bash

# while [ $# -gt 0 ]; do
#     case $1 in
#         -g|-game)  shift; GAME=$1;;
#         -p|-patch) shift; PATCH=$1;;
#         *) OTHER="$OTHER $1";;
#     esac
#     shift
# done

if [ ! -e sdram.hex ]; then
    if [ ! -e rom.bin ]; then
        ln -sf $JTROOT/rom/comsc.rom rom.bin
    fi
    bin2hex <rom.bin >sdram.hex
fi

export GAME_ROM_PATH=rom.bin
export MEM_CHECK_TIME=210_000_000
export BIN2PNG_OPTIONS="--scale"
export CONVERT_OPTIONS="-resize 300%x300%"
GAME_ROM_LEN=$(stat --dereference -c%s $GAME_ROM_PATH)
# export YM2203=1
export M6809=1

if [ ! -e $GAME_ROM_PATH ]; then
    echo Missing file $GAME_ROM_PATH
    exit 1
fi

# Generic simulation script from JTFRAME
echo "Game ROM length: " $GAME_ROM_LEN
sim.sh -mist -d GAME_ROM_LEN=$GAME_ROM_LEN \
    -sysname contra  \
    -d JTFRAME_DWNLD_PROM_ONLY \
    -d JT51_NODEBUG  \
    -def ../../hdl/jtcomsc.def \
    -videow 280 -videoh 240 -d VIDEO_START=1 \
    $*
