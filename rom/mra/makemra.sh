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
    -start gfx1     0x40000 \
    -swapbytes audiocpu \
    -swapbytes maincpu
#    -start subcpu   0x28000 \
#    -start audiocpu 0x30000 \
#    -start mcu      0x38000 \
#    -start proms    0xC0000 \