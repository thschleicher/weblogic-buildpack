#!/bin/sh

# Check Number of arguments
if [ "$#" -lt 2 ]; then
  echo "Usage: triggerDumps.sh <appName> <thread|heap|stats> " 
  echo "    Requires specifying name of the app deployed to CF " 
  echo "    and one of [ thread or heap or stats ] dump " 
  echo "Expects the Agent to stat the target file /home/vcap/tmp/dump<TYPE> "
  echo "Note: Edit the path of the target file as needed"

  exit -1
fi

appName=$1
action=$2

CF_API_VERSION=v2
APP_URL_PREFIX=/${CF_API_VERSION}/apps

# Edit the path of the target file as needed 
# These paths are relative to /home/vcap on the app container
HEAP_DUMP_URL=tmp/dumpHeap
STATS_DUMP_URL=tmp/dumpStats
THREAD_DUMP_URL=tmp/dumpThread

tmpFile=`mktemp -t cfApp.${appName}.XXXX`
#echo TempFile is $tmpFile


CF_TRACE=true cf app $appName >& $tmpFile

appGuid=`grep summary $tmpFile | sed -e 's/summary.*//g;s/GET .*apps//g;s/\///g;' ` 

if [ "$appGuid" == "" ]; then
  echo "ERROR! App $appName not found !!..."
  echo "Exiting...."
  echo ""
  exit -1
fi

#echo "*** AppGuid is $appGuid"

# The running instances id comes with special characters to make them appear with color like: A
#`grep "running " $tmpFile | sed -e 's/ .*//g;s/^[^#]*#//g;s/\[.*//g;s///g' > /tmp/foo`
#
#^[[1;38m^[[0m  ^[[1;38mstate^[[0m  ^[[1;38msince^[[0m    ^[[1;38mcpu^[[0m  ^[[1;38mmemory^[[0m  ^[[1;38mdisk^[[0m······
#^[[1;36m#0^[[0m   running   2014-05-14 02:16:55 PM   0.5%   531.4M of 1G   0 of 1G···
#^[[1;36m#1^[[0m   running   2014-05-20 12:44:53 PM   1.0%   560.9M of 1G   0 of 1G···
# So the character  is a ctrl-[ character, not just a ^ followed by [, so removal of [ and ^ separately wont work

#Default action is Thread Dumps
DUMP_URL=$THREAD_DUMP_URL

case "$action" in
  *heap* )
  action=heap
  DUMP_URL=$HEAP_DUMP_URL;;

  *stat*   )
  action=stats
  DUMP_URL=$STATS_DUMP_URL;;

  * )
  action=thread
  DUMP_URL=$THREAD_DUMP_URL;;
esac


count=0
for instanceId in `grep "running " $tmpFile | sed -e 's/ .*//g;s/^[^#]*#//g;s/\//g;s/\[.*//g' `
do
  #echo "InstanceId is ${instanceId}"

  # Sample URL is /v2/apps/38699180-05c1-4c15-af24-f6c3fce5b1dc/instances/0/files/tmp/dumpThread
  completeDumpUrl="${APP_URL_PREFIX}/${appGuid}/instances/${instanceId}/files/${DUMP_URL}"
  #echo Url: $completeDumpUrl

  count=$((count +1))
  CF_TRACE=false cf curl  $completeDumpUrl

  echo "Triggered $action dump on App: $appName for instance: $instanceId by accessing filepath $DUMP_URL under /home/vcap on application container"
done

rm $tmpFile

echo ""
echo "Finished triggering $action dumps for App: '$appName', across $count instances"
echo ""
