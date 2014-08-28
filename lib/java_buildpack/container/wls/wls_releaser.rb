# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright (c) 2013 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'java_buildpack/container/wls/jvm_arg_helper'
require 'yaml'

module JavaBuildpack
  module Container
    module Wls

      class WlsReleaser
        include JavaBuildpack::Container::Wls::WlsConstants

        def initialize(application, droplet, domain_home, server_name, start_in_wlx_mode)

          @droplet           = droplet
          @application       = application
          @domain_home       = domain_home
          @server_name       = server_name
          @start_in_wlx_mode = start_in_wlx_mode

        end

        # Create a setup script that will handle following
        # 1. Recreate staging directories as the install and domains use the staging env
        # 2. Update java vm arguments
        # 3. Modify the server name using instance index
        def setup

          setup_path
          save_application_details
          add_jvm_args
          rename_server_instance

          "/bin/bash ./#{SETUP_ENV_SCRIPT}"
        end

        private

        # Create a setup script that would recreate staging env's path structure inside the actual DEA
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

        def setup_path
          # The Java Buildpack for WLS creates the complete domain structure and other linkages during staging.
          # The directory used for staging is at /tmp/staged/app. But the actual DEA execution occurs at /home/vcap/app. This discrepancy can result in broken paths and non-startup of the server.
          # So create linkage from /tmp/staged/app to actual environment of /home/vcap/app when things run in real execution
          # Also, this script needs to be invoked before starting the server as it will create the links and also tweak the server args
          # (to listen on correct port, use user supplied jvm args)

          File.open(@application.root.to_s + '/' + SETUP_ENV_SCRIPT, 'w') do |f|

            f.puts '#!/bin/bash                                                                                                        '
            f.puts '                                                                                                                   '
            f.puts 'function fcomp()                                                                                                   '
            f.puts '{                                                                                                                  '
            f.puts '  awk -v n1=$1 -v n2=$2 \'BEGIN{ if (n1 == n2) print "yes"; else print "no"}\'                                                   '
            f.puts '}                                                                                                                  '
            f.puts '                                                                                                                   '
            f.puts 'function multiplyArgs()                                                                                            '
            f.puts '{                                                                                                                  '
            f.puts '  input1=$1                                                                                                        '
            f.puts '  input2=$2                                                                                                        '
            f.puts '  mulResult=`echo $input1 $input2  | awk \'{printf "%d", $1*$2}\' `                                                '
            f.puts '}                                                                                                                  '
            f.puts '                                                                                                                   '
            f.puts 'function divideArgs()                                                                                              '
            f.puts '{                                                                                                                  '
            f.puts '  input1=$1                                                                                                        '
            f.puts '  input2=$2                                                                                                        '
            f.puts '  divResult=`echo $input1 $input2  | awk \'{printf "%.2f", $1/$2}\' `                                              '
            f.puts '}                                                                                                                  '
            f.puts '                                                                                                                   '
            f.puts 'function scaleArgs()                                                                                               '
            f.puts '{                                                                                                                  '
            f.puts '  inputToken=$1                                                                                                    '
            f.puts '  factor=$2                                                                                                        '
            f.puts '  numberToken=`echo $inputToken | tr -cd [0-9]  `                                                                  '
            f.puts '  argPrefix=`echo $inputToken | sed -e \'s/m$//g\' | tr -cd [a-zA-Z-+:=]  `                                        '
            f.puts '  multiplyArgs $numberToken $factor                                                                                '
            f.puts '  # Result saved in mulResult variable                                                                             '
            f.puts '  scaled_number=$mulResult                                                                                                        '
            f.puts '  scaled_token=${argPrefix}${scaled_number}m                                                                '
            f.puts '}                                                                                                                  '
            f.puts '                                                                                                                   '
            f.puts '# There are 5 things handled by this script                                                                        '
            f.puts '                                                                                                                   '
            f.puts '# 1. Create links to mimic staging env and update scripts with jvm options                                         '
            f.puts '# The Java Buildpack for WLS creates complete domain structure and other linkages during staging at                '
            f.puts '#          /tmp/staged/app location                                                                                '
            f.puts '# But the actual DEA execution occurs at /home/vcap/app.                                                           '
            f.puts '# This discrepancy can result in broken paths and non-startup of the server.                                       '
            f.puts '# So create linkage from /tmp/staged/app to actual environment of /home/vcap/app when things run in real execution '
            f.puts '# Create paths that match the staging env, as otherwise scripts will break!!                                       '
            f.puts 'if [ ! -d \"/tmp/staged\" ]; then                                                                                  '
            f.puts '   /bin/mkdir /tmp/staged                                                                                          '
            f.puts 'fi;                                                                                                                '
            f.puts 'if [ ! -d \"/tmp/staged/app\" ]; then                                                                              '
            f.puts '   /bin/ln -s /home/vcap/app /tmp/staged/app                                                                       '
            f.puts 'fi;                                                                                                                '
            f.puts '                                                                                                                   '
          end
        end

        def save_application_details
          File.open(@application.root.to_s + '/' + SETUP_ENV_SCRIPT, 'a') do |f|
            f.puts '                                                                                                                   '
            f.puts '# 2. Save the application details - application name and instance index from VCAP_APPLICATION env variable         '
            f.puts 'APP_NAME=`echo ${VCAP_APPLICATION} | sed -e \'s/,\"/&\n\"/g;s/\"//g;s/,//g\'| grep application_name                ' \
                                          '| cut -d: -f2`                                                                              '
            f.puts 'SPACE_NAME=`echo ${VCAP_APPLICATION} | sed -e \'s/,\"/&\n\"/g;s/\"//g;s/,//g\'| grep space_name                    ' \
                                          '| cut -d: -f2`                                                                              '
            f.puts 'INSTANCE_INDEX=`echo ${VCAP_APPLICATION} | sed -e \'s/,\"/&\n\"/g;s/\"//g;s/,//g\'| grep instance_index            ' \
                                          '| cut -d: -f2`                                                                              '
            f.puts '# The above script will fail on Mac Darwin OS, set Instance Index to 0 when we are not getting numeric value match '
            f.puts 'if ! [ "$INSTANCE_INDEX" -eq "$INSTANCE_INDEX" ] 2>/dev/null; then                                                 '
            f.puts '  INSTANCE_INDEX=0                                                                                                 '
            f.puts '  echo Instance index set to 0                                                                                     '
            f.puts 'fi                                                                                                                 '
            f.puts '# Additional jvm arguments                                                                                         '
            f.puts 'IP_ADDR=`/sbin/ifconfig | grep "inet addr" | grep -v "127.0.0.1" | awk \'{print $2}\' | cut -d: -f2`               '
            f.puts 'export APP_ID_ARGS=" -Dapplication.name=${APP_NAME} -Dapplication.instance-index=${INSTANCE_INDEX}                 '\
                                          ' -Dapplication.space=${SPACE_NAME} -Dapplication.ipaddr=${IP_ADDR} "                        '
            f.puts '                                                                                                                   '
          end
        end

         def add_jvm_args

          # Load the app bundled configurations and re-configure as needed the JVM parameters for the Server VM
          log("JVM config passed via droplet java_opts : #{@droplet.java_opts}")

          JavaBuildpack::Container::Wls::JvmArgHelper.update(@droplet.java_opts)
          JavaBuildpack::Container::Wls::JvmArgHelper.add_wlx_server_mode(@droplet.java_opts, @start_in_wlx_mode)
          log("Consolidated Java Options for Server: #{@droplet.java_opts.join(' ')}")

          wls_pre_classpath  = "export PRE_CLASSPATH='#{@domain_home}/#{WLS_PRE_JARS_CACHE_DIR}/*'"
          wls_post_classpath = "export POST_CLASSPATH='#{@domain_home}/#{WLS_POST_JARS_CACHE_DIR}/*'"

          # Get the Staging env limit
          staging_memory_limit=ENV['MEMORY_LIMIT']
          staging_memory_limit='1024m' unless staging_memory_limit

          File.open(@application.root.to_s + '/' + SETUP_ENV_SCRIPT, 'a') do |f|

            f.puts '                                                                                                                   '
            f.puts '# Check the MEMORY_LIMIT env variable and see if it has been modified compared to staging env                      '
            f.puts '# Possible the app was not restaged to reflect the new MEMORY_LIMITs                                               '
            f.puts '# Following value is from Staging Env MEMORY_LIMIT captured by buildpack                                           '
            f.puts "STAGING_MEMORY_LIMIT=#{staging_memory_limit}                                                                       "
            f.puts '# This comes from actual current execution environment                                                             '
            f.puts 'ACTUAL_MEMORY_LIMIT=${MEMORY_LIMIT}                                                                                '
            f.puts 'STAGING_MEMORY_LIMIT_NUMBER=`echo ${STAGING_MEMORY_LIMIT}| sed -e \'s/m//g\' `                                     '
            f.puts 'ACTUAL_MEMORY_LIMIT_NUMBER=`echo ${ACTUAL_MEMORY_LIMIT}| sed -e \'s/m//g\' `                                       '
            f.puts 'divideArgs $ACTUAL_MEMORY_LIMIT_NUMBER $STAGING_MEMORY_LIMIT_NUMBER                                                '
            f.puts 'scale_factor=$divResult                                                                                            '
            f.puts '                                                                                                                   '
            f.puts '# Scale up or down the heap settings if total memory limits has been changed compared to staging env               '
            f.puts "JVM_ARGS=\"#{@droplet.java_opts.join(' ')}\"                                                                       "
            f.puts 'if [ "$ACTUAL_MEMORY_LIMIT" != "$STAGING_MEMORY_LIMIT" ]; then                                                     '
            f.puts '  # There is difference between staging and actual execution                                                       '
            f.puts '  echo "Detected difference in memory limits of staging and actual Execution environment !!"                       '
            f.puts '  echo "  Staging Env Memory limits: ${STAGING_MEMORY_LIMIT}"                                                      '
            f.puts '  echo "  Runtime Env Memory limits: ${ACTUAL_MEMORY_LIMIT}"                                                       '
            f.puts '  echo "Changing heap settings by factor: $scale_factor "                                                          '
            f.puts '  echo ""                                                                                                          '
            f.puts '  echo "Staged JVM Args: ${JVM_ARGS}"                                                                              '
            f.puts '  heap_mem_tokens=$(echo $JVM_ARGS)                                                                                '
            f.puts '  updated_heap_token=""                                                                                            '
            f.puts '  for token in $heap_mem_tokens                                                                                    '
            f.puts '  do                                                                                                               '
            f.puts '    # Scale for Min/Max heap and the PermGen sizes                                                                 '
            f.puts '    # Ignore other vm args                                                                                         '
            f.puts '    if [[ "$token" == -Xmx* ]] || [[ "$token" == -Xms* ]] || [[ "$token" == *PermSize* ]]; then                    '
            f.puts '                                                                                                                   '
            f.puts '      scaleArgs $token $scale_factor                                                                               '
            f.puts '      # Result stored in scaled_token after call to scaleArgs                                                      '
            f.puts '      updated_heap_token="$updated_heap_token $scaled_token"                                                       '
            f.puts '    else                                                                                                           '
            f.puts '      updated_heap_token="$updated_heap_token $token"                                                              '
            f.puts '    fi                                                                                                             '
            f.puts '  done                                                                                                             '
            f.puts '  JVM_ARGS=$updated_heap_token                                                                                     '
            f.puts '  echo ""                                                                                                          '
            f.puts '  echo "Runtime JVM Args: ${JVM_ARGS}"                                                                             '
            f.puts 'fi                                                                                                                 '
            f.puts '                                                                                                                   '
            f.puts '# 4. Add JVM Arguments by editing the startWebLogic.sh script                                                      '
            f.puts '# Export User defined memory, jvm settings, pre/post classpaths inside the startWebLogic.sh                        '
            f.puts '# Need to use \\" with sed to expand the environment variables                                                     '
            f.puts "sed -i.bak \"s#^DOMAIN_HOME#\\n#{wls_pre_classpath}\\n#{wls_post_classpath}\\n&#1\" #{@domain_home}/startWebLogic.sh"
            f.puts "sed -i.bak \"s#^DOMAIN_HOME#export USER_MEM_ARGS='${APP_ID_ARGS} ${JVM_ARGS} '\\n&#1\" #{@domain_home}/startWebLogic.sh "
            f.puts '                                                                                                                   '
          end
        end

        # Modify the server name to include the instance index in the generated domain
        def rename_server_instance
          File.open(@application.root.to_s + '/' + SETUP_ENV_SCRIPT, 'a') do |f|
            f.puts '                                                                                                                   '
            f.puts '# 5. Server renaming using index to differentiate server instances                                                 '
            f.puts '                                                                                                                   '
            f.puts "SERVER_NAME_TAG=#{@server_name}                                                                                    "
            f.puts 'if [ "${SPACE_NAME}" == "" ]; then                                                                                '
            f.puts '  NEW_SERVER_NAME_TAG=${SERVER_NAME_TAG}-${INSTANCE_INDEX}                                                         '
            f.puts 'else                                                                                                               '
            f.puts '  NEW_SERVER_NAME_TAG=${SPACE_NAME}-${SERVER_NAME_TAG}-${INSTANCE_INDEX}                                           '
            f.puts 'fi                                                                                                                 '
            f.puts "cd #{@domain_home}                                                                                                 "
            f.puts 'mv servers/${SERVER_NAME_TAG} servers/${NEW_SERVER_NAME_TAG}                                                       '
            f.puts 'for config_file in `find . -type f -exec grep -l ${SERVER_NAME_TAG} {} \; `                                        '
            f.puts 'do                                                                                                                 '
            f.puts '  sed -i.bak -e "s/${SERVER_NAME_TAG}/${NEW_SERVER_NAME_TAG}/g" ${config_file}                                     '
            f.puts 'done                                                                                                               '
            f.puts '                                                                                                                   '
          end
        end

        def log(content)
          JavaBuildpack::Container::Wls::WlsUtil.log(content)
        end
      end
    end
  end
end
