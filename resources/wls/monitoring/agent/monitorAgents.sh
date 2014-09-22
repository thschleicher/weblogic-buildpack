#!/bin/bash

TARGET_DIR=$(cd $(dirname $0) && pwd)

AGENT_TYPES_ARRAY=("Heap Stats Thread")
AGENT_PID_ARRAY=""

# Dont kick off right away
# Ruby might get picked as the process to watch rather than java or node-js, as the server is yet to start....
WAIT_INTERVAL_BEFORE_KICKOFF=30

function startAgent {
  type=$1

  completeAgent=dump${type}Agent

  agentLog=${completeAgent}.log
  agentScript=${completeAgent}.sh

  $TARGET_DIR/${agentScript}   $WAIT_INTERVAL_BEFORE_KICKOFF  2>&1  >  $TARGET_DIR/${agentLog}   &
  pid=$!
  echo Kicked off $type Agent with pid: $pid with output going to $TARGET_DIR/${agentLog}
  case "$type" in
     "Heap") heapAgentPid=$pid;;
     "Stats") statsAgentPid=$pid;;
     "Thread") threadAgentPid=$pid;;
  esac
}

function checkAgent {
  type=$1
  pid=$2

  ps -p $pid 2>&1 >/dev/null;
  status=$?
  if [ "$status" != "0" ]; then
    startAgent $type
  fi
}

function checkAllAgents {

  index=0
  for type in `echo ${AGENT_TYPES_ARRAY}`
  do
    #echo "Checking ${AGENT_TYPES_ARRAY[${index}]}Agent with pid: ${AGENT_PID_ARRAY[${index}]} "
    checkAgent $type ${AGENT_PID_ARRAY[${index}]}
    AGENT_PID_ARRAY[${index}]=$pid
    index=$((index+1))
  done
}

function startAllAgents
{
  for type in `echo ${AGENT_TYPES_ARRAY}`
  do
    startAgent $type
    AGENT_PID_LIST+=" $pid";
  done
  #echo $AGENT_PID_LIST

  AGENT_PID_ARRAY=($AGENT_PID_LIST)
}

function signalChildren {
  for var in `echo ${AGENT_PID_ARRAY}`
  do
    if ps -p $var > /dev/null
    then
      echo "sending $1 to $var"
      kill -s $1 $var
    fi
  done
}

startAllAgents
while ( test 1 )
do
  sleep 60
  checkAllAgents
done

# Use this for simple kick off agents without monitoring/restarts...
#$TARGET_DIR/dumpHeapAgent.sh   $WAIT_INTERVAL_BEFORE_KICKOFF  2>&1  >  $TARGET_DIR/dumpHeapAgent.log   &
#$TARGET_DIR/dumpStatsAgent.sh  $WAIT_INTERVAL_BEFORE_KICKOFF  2>&1  >  $TARGET_DIR/dumpStatsAgent.log  &
#$TARGET_DIR/dumpThreadAgent.sh $WAIT_INTERVAL_BEFORE_KICKOFF  2>&1  >  $TARGET_DIR/dumpThreadAgent.log &