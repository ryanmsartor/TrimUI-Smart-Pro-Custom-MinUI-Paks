#!/bin/sh

#overclock.elf userspace 2 1344 384 1080 0

while :; do
    syncsettings.elf
done &
LOOP_PID=$!

echo $0 $*
RA_DIR=/mnt/SDCARD/Tools/$PLATFORM/RetroArch.pak
EMU_DIR=/mnt/SDCARD/Emus/$PLATFORM/SCUMMVM.pak

$EMU_DIR/performance.sh


cd "$RA_DIR"
HOME=$RA_DIR/ $RA_DIR/ra64.trimui -v -L $RA_DIR/.retroarch/cores/scummvm_libretro.so "$*"


kill $LOOP_PID


