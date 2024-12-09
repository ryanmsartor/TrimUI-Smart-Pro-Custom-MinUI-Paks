#!/bin/sh

#overclock.elf userspace 2 1344 384 1080 0

while :; do
    syncsettings.elf
done &
LOOP_PID=$!

echo $0 $*
RA_DIR=/mnt/SDCARD/Tools/tg3040/RetroArch.pak
EMU_DIR=/mnt/SDCARD/Emus/tg3040/EASYRPG.pak

$EMU_DIR/performance.sh


cd "$RA_DIR"
HOME=$RA_DIR/ $RA_DIR/ra64.trimui -v -L $RA_DIR/.retroarch/cores/easyrpg_libretro.so "$*"


kill $LOOP_PID


