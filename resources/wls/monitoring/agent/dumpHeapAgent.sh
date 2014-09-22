#!/bin/bash

TARGET_DIR=$(cd $(dirname $0) && pwd)

# Dont kick off right away
# Ruby might get picked as the process to watch rather than java or node-js as the server is yet to start....
DELAY_INTERVAL_BEFORE_KICKOFF=$1

TARGET_ACTION=Heap

# The DUMP_FOLDER should correspond with the trigger script that checks for the file
# The target file to monitor to kick off heap dump
DUMP_MONITOR_TARGET="/home/vcap/tmp/dumpHeap"

source $TARGET_DIR/commonUtil.sh

#function touchAndSaveTimestamp() {
#  `touch $DUMP_MONITOR_TARGET`
#  lastSavedAccessTimestamp=`stat -c %X $DUMP_MONITOR_TARGET`
#}


function setJavaTools()
{
   export SERVER_PID=`ps -ef | grep "bin/java" | grep -v "grep" | tail -1 | awk '{ print $2 }' `
   export DUMP_TOOL=`find / -name jmap  2>/dev/null`
   if [ "$DUMP_TOOL" == "" ]; then
     echo "ERROR! No jmap found...!!"
   fi
}

function buildJavaDumpCommand()
{
   if [ "$DUMP_TOOL" != "" ]; then
     export DUMP_COMMAND="$DUMP_TOOL -dump:live,format=b,file=$DUMP_FOLDER/$day/${APP_NAME}.${SERVER_PID}.${day}.${curTimestamp}.hprof $SERVER_PID"
     echo "DUMP_COMMAND is $DUMP_COMMAND"
   fi
}

function setRubyTools()
{
   export SERVER_PID=`ps -ef | grep "bin/ruby" | grep -v "grep" | awk '{ print $2 }' `
   #export DUMP_TOOL=`find / -name jmap  2>/dev/null`
   #export DUMP_COMMAND="$DUMP_TOOL $SERVER_PID "
}

function buildRubyDumpCommand()
{
   export DUMP_COMMAND="Please configure/edit the DUMP_COMMAND for RUBY"
   echo "Please configure/edit the DUMP_COMMAND for RUBY"
}

function setHeapDumpCommand()
{
  if [ "$targetType" == "JAVA" ]; then
    buildJavaDumpCommand
  elif [ "$targetType" == "RUBY" ]; then
    buildRubyDumpCommand
  fi
}

# Check if we have to sleep before the kick off so the server side application has started
if [ -n "$DELAY_INTERVAL_BEFORE_KICKOFF" ]; then
  sleep $DELAY_INTERVAL_BEFORE_KICKOFF
fi

APP_NAME=$(findAppLabel)
targetType=$(findTargetType)
echo "Server Process detected: $targetType"
if [ "$targetType" == "JAVA" ]; then
  echo "Calling setJavaTools.."
  setJavaTools
elif [ "$processType" == "RUBY" ]; then
  setRubyTools
fi

touchAndSaveTimestamp

while (true)
do
  curTime=`date +%s`
  day=`date +%m_%d_%y`

  lastAccessTimestamp=`stat -c %X $DUMP_MONITOR_TARGET`
  #echo "LastSavedAccessTime: $lastSavedAccessTimestamp"
  #echo "LastAccessTime: $lastAccessTimestamp"

  accessTimeDiff=$((lastAccessTimestamp- lastSavedAccessTimestamp))
  #echo "Diff in time: $accessTimeDiff "

  if [ "$accessTimeDiff" -gt 2 ]; then
    curTimestamp=`date +%H_%M_%S`
    mkdir -p $DUMP_FOLDER/$day 2>/dev/null
    echo Detected $TARGET_ACTION Dump Trigger action for App: $APP_NAME

    setHeapDumpCommand
    echo $DUMP_COMMAND
    $DUMP_COMMAND

    touchAndSaveTimestamp
  fi

  sleep $SLEEP_INTERVAL
done

