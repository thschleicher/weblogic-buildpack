#!/bin/bash

# Create a pre-start setup script that would recreate staging env's path structure inside the actual DEA
# runtime env and also embed additional jvm arguments at server startup

# The Java Buildpack for WLS creates the complete domain structure and other linkages during staging.
# The directory used for staging is under /tmp/staged/
# But the actual DEA execution occurs at /home/vcap/.
# This discrepancy can result in broken paths and non-start of the server.
# So create linkage from /tmp/staged/app to actual environment of /home/vcap/app when things run in real execution
# Also, this script needs to be invoked before starting the server as it will create the links and
# Also tweak the server args (to listen on correct port, use user supplied jvm args).
#
# Additional steps handled by the script include:
#   Add -Dapplication.name, -Dapplication.space , -Dapplication.ipaddr and -Dapplication.instance-index
#      as jvm arguments to help identify the server instance from within a DEA vm
#      Example: -Dapplication.name=wls-test -Dapplication.instance-index=0
#               -Dapplication.space=sabha -Dapplication.ipaddr=10.254.0.210
#   Renaming of the server to include space name and instance index (For example: myserver becomes myspace-myserver-5)
#   Resizing of the heap settings based on actual MEMORY_LIMIT variable in the runtime environment
#     - Example: during initial cf push, memory was specified as 1GB and so heap sizes were hovering around 700M
#                Now, user uses cf scale to change memory settings to 2GB or 512MB
#                The factor to use is deterined by doing Actual/Staging and
#                heaps are resized by that factor for actual runtime execution without requiring full staging
#      Sample resizing :
#      Detected difference in memory limits of staging and actual Execution environment !!
#         Staging Env Memory limits: 512m
#         Runtime Env Memory limits: 1512m
#      Changing heap settings by factor: 2.95
#      Staged JVM Args: -Xms373m -Xmx373m -XX:PermSize=128m -XX:MaxPermSize=128m  -verbose:gc ....
#      Runtime JVM Args: -Xms1100m -Xmx1100m -XX:PermSize=377m -XX:MaxPermSize=377m -verbose:gc ....

# Note: All 'REPLACE_..._MARKER' variables will be replaced by actual values by the buildpack during staging

function fcomp()
{
  awk -v n1=$1 -v n2=$2 'BEGIN{ if (n1 == n2) print "yes"; else print "no"}'
}

function multiplyArgs()
{
  input1=$1
  input2=$2
  mulResult=`echo $input1 $input2  | awk '{printf "%d", $1*$2}' `
}

function divideArgs()
{
  input1=$1
  input2=$2
  divResult=`echo $input1 $input2  | awk '{printf "%.2f", $1/$2}' `
}

function scaleArgs()
{
  inputToken=$1
  factor=$2
  numberToken=`echo $inputToken | tr -cd [0-9]  `
  argPrefix=`echo $inputToken | sed -e 's/m$//g' | tr -cd [a-zA-Z-+:=]  `
  multiplyArgs $numberToken $factor
  # Result saved in mulResult variable
  scaled_number=$mulResult
  scaled_token=${argPrefix}${scaled_number}m
}



# 1. Create links to mimic staging env and update scripts with jvm options
# The Java Buildpack for WLS creates complete domain structure and other linkages during staging at
#          /tmp/staged/app location
# But the actual DEA execution occurs at /home/vcap/app.
# This discrepancy can result in broken paths and non-startup of the server.
# So create linkage from /tmp/staged/app to actual environment of /home/vcap/app when things run in real execution
# Create paths that match the staging env, as otherwise scripts will break!!

# Directory containing the app folder
# Will be set by buildpack to staging directory
VCAP_ROOT=REPLACE_VCAP_ROOT_MARKER

# Check if the directory exists
# Staging uses /tmp/staged
# Runtime uses /home/vcap
if [ ! -d \"${VCAP_ROOT}\" ]; then
   /bin/mkdir ${VCAP_ROOT}
fi;

if [ ! -d \"${VCAP_ROOT}/app\" ]; then
   /bin/ln -s /home/vcap/app ${VCAP_ROOT}/app
fi;


# 2. Save the application details - application name and instance index from VCAP_APPLICATION env variable
APP_NAME=`echo ${VCAP_APPLICATION} | sed -e 's/,\"/&\n\"/g;s/\"//g;s/,//g'| grep application_name | cut -d: -f2`

SPACE_NAME=`echo ${VCAP_APPLICATION} | sed -e 's/,\"/&\n\"/g;s/\"//g;s/,//g'| grep space_name | cut -d: -f2`

IP_ADDR=`/sbin/ifconfig | grep "inet addr" | grep -v "127.0.0.1" | awk '{print $2}' | cut -d: -f2`

INSTANCE_INDEX=`echo ${VCAP_APPLICATION} | sed -e 's/,\"/&\n\"/g;s/\"//g;s/,//g'| grep instance_index| cut -d: -f2`

# The above script will fail on Mac Darwin OS, set Instance Index to 0 when we are not getting numeric value match
if ! [ "$INSTANCE_INDEX" -eq "$INSTANCE_INDEX" ] 2>/dev/null; then
  INSTANCE_INDEX=0
  echo Instance index set to 0
fi


# Get the Staging env Memory limit

STAGING_MEMORY_LIMIT=REPLACE_STAGING_MEMORY_LIMIT_MARKER

# Check the MEMORY_LIMIT env variable and see if it has been modified compared to staging env
# Possible the app was not restaged to reflect the new MEMORY_LIMITs
# Following value is from Staging Env MEMORY_LIMIT captured by buildpack
# This comes from actual current execution environment
ACTUAL_MEMORY_LIMIT=${MEMORY_LIMIT}

STAGING_MEMORY_LIMIT_NUMBER=`echo ${STAGING_MEMORY_LIMIT}| sed -e 's/m//g' `
ACTUAL_MEMORY_LIMIT_NUMBER=`echo ${ACTUAL_MEMORY_LIMIT}| sed -e 's/m//g' `

# Find the scaling factor
divideArgs $ACTUAL_MEMORY_LIMIT_NUMBER $STAGING_MEMORY_LIMIT_NUMBER
scale_factor=$divResult


# Replace with the actual java memory args passed down from the buildpack
JVM_ARGS="REPLACE_JAVA_ARGS_MARKER"

# Scale up or down the heap settings if total memory limits has been changed compared to staging env

if [ "${ACTUAL_MEMORY_LIMIT}X" != "X" -a "$ACTUAL_MEMORY_LIMIT" != "$STAGING_MEMORY_LIMIT" ]; then
  # There is difference between staging and actual execution
  echo "Detected difference in memory limits of staging and actual Execution environment !!"
  echo "  Staging Env Memory limits: ${STAGING_MEMORY_LIMIT}"
  echo "  Runtime Env Memory limits: ${ACTUAL_MEMORY_LIMIT}"
  echo "Changing heap settings by factor: $scale_factor "
  echo ""
  echo "Staged JVM Args: ${JVM_ARGS}"
  heap_mem_tokens=$(echo $JVM_ARGS)
  updated_heap_token=""
  for token in $heap_mem_tokens
  do
    # Scale for Min/Max heap and the PermGen sizes
    # Ignore other vm args
    if [[ "$token" == -Xmx* ]] || [[ "$token" == -Xms* ]] || [[ "$token" == *PermSize* ]]; then

      scaleArgs $token $scale_factor
      # Result stored in scaled_token after call to scaleArgs
      updated_heap_token="$updated_heap_token $scaled_token"
    else
      updated_heap_token="$updated_heap_token $token"
    fi
  done
  JVM_ARGS=$updated_heap_token
  echo ""
  echo "Runtime JVM Args: ${JVM_ARGS}"
fi

# 4. Add JVM Arguments by editing the startWebLogic.sh script
# Export User defined memory, jvm settings, pre/post classpaths inside the startWebLogic.sh
# Need to use \\" with sed to expand the environment variables

# Additional jvm arguments

wls_pre_classpath='export PRE_CLASSPATH="REPLACE_DOMAIN_HOME_MARKER/REPLACE_WLS_PRE_JARS_CACHE_DIR_MARKER/*"'
wls_post_classpath='export POST_CLASSPATH="REPLACE_DOMAIN_HOME_MARKER/REPLACE_WLS_POST_JARS_CACHE_DIR_MARKER/*"'

export APP_ID_ARGS=" -Dapplication.name=${APP_NAME} -Dapplication.instance-index=${INSTANCE_INDEX} \
                     -Dapplication.space=${SPACE_NAME} -Dapplication.ipaddr=${IP_ADDR} -Dapplication.host=${HOSTNAME}"


sed -i.bak "s#^DOMAIN_HOME#\\n${wls_pre_classpath}\\n${wls_post_classpath}\\n&#1" REPLACE_DOMAIN_HOME_MARKER/startWebLogic.sh
sed -i.bak "s#^DOMAIN_HOME#export USER_MEM_ARGS='${JVM_ARGS} ${APP_ID_ARGS} '\\n&#1" REPLACE_DOMAIN_HOME_MARKER/startWebLogic.sh


# 5. Server renaming using index to differentiate server instances

SERVER_NAME_TAG=REPLACE_SERVER_NAME_MARKER
NEW_SERVER_NAME_TAG=${SERVER_NAME_TAG}-${INSTANCE_INDEX}

# Go to the domain home
cd REPLACE_DOMAIN_HOME_MARKER

# Move the server folder to modified server name
mv servers/${SERVER_NAME_TAG} servers/${NEW_SERVER_NAME_TAG}

# Find and replace all references of the server name to newly modified server name (sandwiched between space and instance index)
for config_file in `find . -type f -exec grep -l ${SERVER_NAME_TAG} {} \; `
do
  sed -i.bak -e "s/${SERVER_NAME_TAG}/${NEW_SERVER_NAME_TAG}/g" ${config_file}
done
