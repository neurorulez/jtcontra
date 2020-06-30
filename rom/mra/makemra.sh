#!/bin/bash
mame2dip contra.xml -rbf jtcontra \
    -frac gfx1 2 \
    -frac gfx2 2 \
    -ignore plds \
    -ignore upd \
    -swapbytes audiocpu \
    -swapbytes maincpu

mame2dip comsc.xml -rbf jtcomsc \
    -frac gfx1 2 \
    -frac gfx2 2 \
    -ignore plds \
    -ignore upd \
    -start audiocpu 0x30000 \
    -start gfx1     0x40000 \
    -start gfx2     0x140000 \
    -start proms    0x240000 \
    -swapbytes audiocpu \
    -swapbytes maincpu  \
    -dipbase 8
#    -start subcpu   0x28000 \
#    -start audiocpu 0x30000 \
#    -start mcu      0x38000 \
#    -start proms    0xC0000 \

mame2dip hcastle.xml -rbf jtcastle \
    -frac gfx1 2 \
    -frac gfx2 2 \
    -ignore plds \
    -ignore upd \
    -swapbytes audiocpu \
    -start audiocpu 0x30000 \
    -start gfx1     0x40000 \
    -start gfx2     0x140000 \
    -start proms    0x240000 \
    -swapbytes maincpu

mame2dip mx5000.xml -rbf jtmx5000 \
    -frac gfx1 2 \
    -frac gfx2 2 \
    -ignore plds \
    -ignore upd \
    -swapbytes audiocpu \
    -start audiocpu 0x30000 \
    -start gfx1     0x40000 \
    -start gfx2     0x140000 \
    -start proms    0x240000 \
    -swapbytes maincpu