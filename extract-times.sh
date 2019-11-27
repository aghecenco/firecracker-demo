#!/bin/bash

DATA_DIR="output"
DEST="$PWD/data.log"

rm -f $DEST

pushd $DATA_DIR > /dev/null

COUNT=`ls -l fc-sb* | wc -l`
COUNT=$((COUNT / 2 - 1))

for i in `seq 0 $COUNT`; do
    boot_time=`grep "Guest-boot" fc-sb$i-log -m 1 | awk '{print \$12}'`
    resume_time=`grep "Guest-boot" fc-sb$i-resumed-log -m 1 | awk '{print \$12}'`
    echo "$i $boot_time $resume_time" >> $DEST
done

popd > /dev/null

