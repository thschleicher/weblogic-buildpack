#!/bin/bash

TARGET_DIR=$(cd $(dirname $0) && pwd)

#Kick off the monitorAgents script in background that will then kick off the individual agents and also monitor them continuously
/bin/bash $TARGET_DIR/monitorAgents.sh &
