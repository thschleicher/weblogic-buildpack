#!/bin/bash


function findAppLabel()
{
  appName=`echo ${VCAP_APPLICATION} | sed -e 's/,\"/&\n\"/g;s/\"//g;s/,//g'| grep application_name | cut -d: -f2`
  appInst=`echo ${VCAP_APPLICATION} | sed -e 's/,\"/&\n\"/g;s/\"//g;s/,//g'| grep instance_index| cut -d: -f2`
  echo ${appName}-${appInst}
}


function oldFindAppLabel()
{
  old_IFS=$IFS
  IFS=","
  for envAppContent in `cat /home/vcap/logs/env.log`
  do
    #if [[ "$envAppContent"  == *instance_index* ]]; then
    #  appInst=`echo $envAppContent | sed -e 's/\"//g;s/instance_index://g;s/^[ \t]*//;s/[ \t]*$//'`
    #elif [[ "$envAppContent"  == *application_name* ]]; then
    #  appName=`echo $envAppContent | sed -e 's/\"//g;s/application_name://g;s/^[ \t]*//;s/[ \t]*$//'`
    #fi
    case "$envAppContent" in
      *instance_index* )
      appInst=`echo $envAppContent | sed -e 's/\"//g;s/instance_index://g;s/^[ \t]*//;s/[ \t]*$//'`;;

      *application_name* )
      appName=`echo $envAppContent | sed -e 's/\"//g;s/application_name://g;s/^[ \t]*//;s/[ \t]*$//'`;;
    esac

  done
  IFS=$old_IFS
  echo ${appName}-${appInst}
}

function findTargetType()
{
  old_IFS=$IFS
  IFS=$'\n'
  appType="RUBY"
  for process in `ps aux --sort rss | tail -5`
  do
    #if [[ "$process"  == *\/java* ]]; then
    #  appType="JAVA"
    #elif [[ "$process"  == *\/ruby* ]]; then
    #  appType="RUBY"
    #fi
    case "$process" in
      *\/java* )
      appType="JAVA";;

      *\/ruby* )
      appType="RUBY";;
    esac
  done
  IFS=$old_IFS
  echo ${appType}
}

function touchAndSaveTimestamp()
{
  `touch $DUMP_MONITOR_TARGET`
  lastSavedAccessTimestamp=`stat -c %X $DUMP_MONITOR_TARGET`
}

SLEEP_INTERVAL=30

DUMP_FOLDER="/home/vcap/dumps"
mkdir -p $DUMP_FOLDER 2>/dev/null

