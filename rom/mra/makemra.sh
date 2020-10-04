#!/bin/bash
(cd $JTFRAME/cc; make) || exit $?

MAKELIST=all

while [ $# -gt 0 ]; do
    case $1 in
        -rom)
            MAKEROM=1;;
        -core)
            shift
            MAKELIST=$1;;
        -h|-help)
            cat <<EOF
makemra.sh creates MRA files for some cores. Optional arguments:
    -rom        create .rom files too using the mra tool
    -core       specify for which core the files will be generated. Valid values
                labrun
                contra
                comsc
                mx5000
    -h | -help  shows this message
EOF
            exit 1;;
        *)
            echo "ERROR: unknown argument " $MAKEROM
            exit 1;;
    esac
    shift
done

if [[ $MAKELIST = all ||  $MAKELIST = labrun ]]; then
    if [ ! -e labrun.xml ]; then
        mamefilter labyrunr > labrun.xml || exit $?
    fi
    ALT=_alt/"Labyrinth Runner"
    mkdir -p $ALT
    COMMON="labrun.xml -rbf jtlabrun -swapbytes maincpu -dipbase 8"

    mame2dip $COMMON \
        -machine tricktrp \
        -frac gfx1 2 -altfolder "$ALT" \
        -order-roms gfx1 0 2 1 3

    mame2dip $COMMON \
        -machine labyrunr \
        -altfolder "$ALT" -swapbytes gfx1

    mame2dip $COMMON \
        -machine labyrunrk \
        -frac gfx1 2 -altfolder "$ALT" \
        -order-roms gfx1 0 2 1 3
fi

if [[ $MAKELIST = all ||  $MAKELIST = contra ]]; then
    mame2dip contra.xml -rbf jtcontra \
        -frac gfx1 2 \
        -frac gfx2 2 \
        -ignore plds \
        -ignore upd \
        -swapbytes audiocpu \
        -swapbytes maincpu
fi

if [[ $MAKELIST = all ||  $MAKELIST = comsc ]]; then
    mame2dip comsc.xml -rbf jtcomsc \
        -frac gfx1 2 \
        -frac gfx2 2 \
        -ignore plds \
        -start audiocpu 0x30000 \
        -start gfx1     0x40000 \
        -start gfx2     0x140000 \
        -start proms    0x2C0000 \
        -swapbytes audiocpu \
        -swapbytes maincpu  \
        -swapbytes upd  \
        -dipbase 8 \
        -dipshift DSW3 4
    #    -start subcpu   0x28000 \
    #    -start audiocpu 0x30000 \
    #    -start mcu      0x38000 \
    #    -start proms    0xC0000 \
    mra -A -s 'Combat School (joystick).mra'
    sed -i /Unknown/d 'Combat School (joystick).arc'
    # Delete Unknown DIP switches
    sed -i /Unknown/d 'Combat School (joystick).mra'
fi

if [[ $MAKELIST = all ||  $MAKELIST = castle ]]; then
    mame2dip hcastle.xml -rbf jtcastle \
        -frac gfx1 2 \
        -frac gfx2 2 \
        -ignore plds \
        -ignore upd \
        -swapbytes audiocpu \
        -start audiocpu 0x30000 \
        -start gfx1     0x40000 \
        -start gfx2     0x140000 \
        -start proms    0x2C0000 \
        -swapbytes maincpu
fi

if [[ $MAKELIST = all ||  $MAKELIST = mx5000 ]]; then
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
fi

