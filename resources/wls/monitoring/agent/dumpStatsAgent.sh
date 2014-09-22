#!/bin/bash

TARGET_DIR=$(cd $(dirname $0) && pwd)

# Dont kick off right away
# Ruby might get picked as the process to watch rather than java or node-js as the server is yet to start....
DELAY_INTERVAL_BEFORE_KICKOFF=$1

TARGET_ACTION=Stats
DUMP_FILE_PREFIX=stats

# The DUMP_FOLDER should correspond with the trigger script that checks for the file
# The target file to monitor to kick off stats dump
DUMP_MONITOR_TARGET="/home/vcap/tmp/dumpStats"

source $TARGET_DIR/commonUtil.sh

function touchAndSaveTimestamp() {
  `touch $DUMP_MONITOR_TARGET`
  lastSavedAccessTimestamp=`stat -c %X $DUMP_MONITOR_TARGET`
}


# Check if we have to sleep before the kick off so the server side application has started
if [ -n "$DELAY_INTERVAL_BEFORE_KICKOFF" ]; then
  sleep $DELAY_INTERVAL_BEFORE_KICKOFF
fi

APP_NAME=$(findAppLabel)

touchAndSaveTimestamp

while (true)
do
  curTime=`date +%s`
  day=`date +%m_%d_%y`

  lastAccessTimestamp=`stat -c %X $DUMP_MONITOR_TARGET`

  accessTimeDiff=$((lastAccessTimestamp- lastSavedAccessTimestamp))
  #echo "Diff in time: $accessTimeDiff "

  if [ "$accessTimeDiff" -gt 2 ]; then

    curTimestamp=`date +%H_%M_%S`
    mkdir -p $DUMP_FOLDER/$day 2>/dev/null
    dumpFile=$DUMP_FOLDER/$day/${DUMP_FILE_PREFIX}.${APP_NAME}.${day}.${curTimestamp}.txt

    echo Detected $TARGET_ACTION Dump Trigger action for App: $APP_NAME
    echo Dumping $TARGET_ACTION to $dumpFile
    echo "$TARGET_ACTION Dumps for Server: $APP_NAME at `date`" >> $dumpFile
    echo "" >> $dumpFile

    echo "Process stats" >> $dumpFile
    echo "-------------" >> $dumpFile
    ps auxww --sort rss >> $dumpFile
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" >> $dumpFile

    echo "" >> $dumpFile
    echo "Environment variables" >> $dumpFile
    echo "---------------------" >> $dumpFile
    env >> $dumpFile
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" >> $dumpFile

    echo "" >> $dumpFile
    echo "Top Processes " >> $dumpFile
    echo "-------------" >> $dumpFile
    top -n 1 -b  >> $dumpFile
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" >> $dumpFile

    echo "" >> $dumpFile
    echo "VMStat " >> $dumpFile
    echo "------" >> $dumpFile
    vmstat -n 2 2  >> $dumpFile
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" >> $dumpFile

    echo "" >> $dumpFile
    echo "MPStat " >> $dumpFile
    echo "------" >> $dumpFile
    mpstat  >> $dumpFile
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" >> $dumpFile

    echo "" >> $dumpFile
    echo "VCAP related Environment variables and staging logs" >> $dumpFile
    echo "---------------------------------------------------" >> $dumpFile
    cat /home/vcap/logs/env.log  >> $dumpFile
    echo "" >> $dumpFile
    echo "Staging Task Logs" >> $dumpFile
    echo "-----------------" >> $dumpFile
    cat /home/vcap/logs/staging_task.log  >> $dumpFile
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" >> $dumpFile

    touchAndSaveTimestamp
  fi

  sleep $SLEEP_INTERVAL
done

