#!/bin/bash
# Script called on exit of the app instance
# Report server death as well as do any cleanup/backup activities before warden container gets cleaned up

# Check Env variable SHUTDOWN_WAIT_INTERVAL to use as sleep interval
# Otherwise default to 30 seconds
SLEEP_INTERVAL=${SHUTDOWN_WAIT_INTERVAL:=30}

IP_ADDR=`/sbin/ifconfig | grep "inet addr" | grep -v "127.0.0.1" | awk '{print $2}' | cut -d: -f2`

APP_NAME=`echo ${VCAP_APPLICATION} | sed -e 's/,\"/&\n\"/g;s/\"//g;s/,//g'| grep "application_name:" | cut -d: -f2`

SPACE_NAME=`echo ${VCAP_APPLICATION} | sed -e 's/,\"/&\n\"/g;s/\"//g;s/,//g'| grep "space_name:" | cut -d: -f2`

INSTANCE_INDEX=`echo ${VCAP_APPLICATION} | sed -e 's/,\"/&\n\"/g;s/\"//g;s/,//g'| grep "instance_index:" | cut -d: -f2`

APP_ID=`echo ${VCAP_APPLICATION} | sed -e 's/,\"/&\n\"/g;s/\"//g;s/,//g'| grep "application_id:" | cut -d: -f2`

START_TIME=`echo ${VCAP_APPLICATION} | sed -e 's/,\"/&\n\"/g;s/\"//g;s/,//g'| grep "started_at:" | sed -e 's/started_at://'`

# The above script will fail on Mac Darwin OS, set Instance Index to 0 when we are not getting numeric value match
if ! [ "$INSTANCE_INDEX" -eq "$INSTANCE_INDEX" ] 2>/dev/null; then
  INSTANCE_INDEX=0
  echo Instance index set to 0
fi

IP_ADDR=`/sbin/ifconfig | grep "inet addr" | grep -v "127.0.0.1" | awk '{print $2}' | cut -d: -f2`

echo "App Instance went down either due to user action or other reasons!!"
echo ""
echo "                  App Details"
echo ---------------------------------------------------------------
echo " Name of Application    : ${APP_NAME}                        "
echo " App GUID               : ${APP_ID}                          "
echo " Space                  : ${SPACE_NAME}                      "
echo " Instance Index         : ${INSTANCE_INDEX}                  "
echo " Warden Container Name  : ${HOSTNAME}                        "
echo " Warden Container IP    : ${IP_ADDR}                         "
echo " Start time             : ${START_TIME}                      "
echo " Stop time              : `date "+%Y-%m-%d %H:%M:%S %z"`     "
echo ---------------------------------------------------------------
echo ""

echo "Shutdown wait interval set to $SLEEP_INTERVAL seconds (using env var SHUTDOWN_WAIT_INTERVAL, default 30)"
echo ""

echo Modify this script as needed to upload core files, logs or other dumps to some remote file server
echo ""

echo Use cf curl to download the relevant files from this particular instance
echo "    cf curl /v2/apps/${APP_ID}/instances/${INSTANCE_INDEX}/files "
echo ""
echo "Container will exit after $SLEEP_INTERVAL seconds!!"
echo ""

sleep $SLEEP_INTERVAL
echo "Container exiting!!!"

