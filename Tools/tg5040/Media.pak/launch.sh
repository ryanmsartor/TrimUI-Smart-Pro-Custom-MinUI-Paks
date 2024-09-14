#!/bin/sh
echo $0 $*
progdir=`dirname "$0"`
cd $progdir
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$progdir

echo 1 > /tmp/stay_awake

mount --bind /sdcard/tools/media.pak/res /user/trimui/res/

while :; do
    syncsettings.elf
done &
LOOP_PID=$!

./mediaplayer

echo 0 > /tmp/stay_awake
kill $LOOP_PID