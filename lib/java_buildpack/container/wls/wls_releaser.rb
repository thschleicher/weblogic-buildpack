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

          "/bin/sh ./#{SETUP_ENV_SCRIPT}"
        end

        private

        # Create a setup script that would recreate staging env's path structure inside the actual DEA
        # runtime env and also embed additional jvm arguments at server startup as staging occurs under /tmp/staging
        # while actual runtime execution occurs under /home/vcap
        def setup_path
          # The Java Buildpack for WLS creates the complete domain structure and other linkages during staging.
          # The directory used for staging is at /tmp/staged/app. But the actual DEA execution occurs at /home/vcap/app. This discrepancy can result in broken paths and non-startup of the server.
          # So create linkage from /tmp/staged/app to actual environment of /home/vcap/app when things run in real execution
          # Also, this script needs to be invoked before starting the server as it will create the links and also tweak the server args
          # (to listen on correct port, use user supplied jvm args)

          File.open(@application.root.to_s + '/' + SETUP_ENV_SCRIPT, 'w') do |f|

            f.puts '#!/bin/sh                                                                                                          '
            f.puts '# There are 4 things handled by this script                                                                        '
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
            f.puts '   /bin/ln -s `pwd` /tmp/staged/app                                                                                '
            f.puts 'fi;                                                                                                                '
            f.puts '                                                                                                                   '
            f.puts '# The Yaml configuration files used for creating the WLS Domain should be moved so they are not served accidentally'
            f.puts '# by the web application                                                                                           '
            f.puts '# Move them to the APP-INF or WEB-INF folder under the application.                                                '
            f.puts '# Not moving the .java-buildpack.log or the .monitor folder                                                        '
            f.puts 'mv /tmp/staged/app/.wls /tmp/staged/app/*-INF 2>/dev/null                                                          '
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
            f.puts 'IP_ADDR=`ifconfig | grep "inet addr" | grep -v "127.0.0.1" | awk \'{print $2}\' | cut -d: -f2`                     '
            f.puts 'export APP_ID_ARGS=" -Dapplication.name=${APP_NAME} -Dapplication.instance-index=${INSTANCE_INDEX}                 '\
                                          ' -Dapplication.space=${SPACE_NAME} -Dapplication.ipaddr=${IP_ADDR} "                        '
            f.puts '                                                                                                                   '
          end
        end

        # Create a setup script that would recreate staging env's path structure inside the actual DEA
        # runtime env and also embed additional jvm arguments at server startup as staging occurs under /tmp/staging, while
        # The Java Buildpack for WLS creates the complete domain structure and other linkages during staging.
        # The directory used for staging is at /tmp/staged/app
        # But the actual DEA execution occurs at /home/vcap/app. This discrepancy can result in broken paths and non-startup of the server.
        # So create linkage from /tmp/staged/app to actual environment of /home/vcap/app when things run in real execution
        # Also, this script needs to be invoked before starting the server as it will create the links and also tweak the server args
        # (to listen on correct port, use user supplied jvm args)
        #  actual runtime execution occurs under /home/vcap
        def add_jvm_args

          # Load the app bundled configurations and re-configure as needed the JVM parameters for the Server VM
          log("JVM config passed via droplet java_opts : #{@droplet.java_opts}")

          JavaBuildpack::Container::Wls::JvmArgHelper.update(@droplet.java_opts)
          JavaBuildpack::Container::Wls::JvmArgHelper.add_wlx_server_mode(@droplet.java_opts, @start_in_wlx_mode)
          log("Consolidated Java Options for Server: #{@droplet.java_opts.join(' ')}")

          wls_pre_classpath  = "export PRE_CLASSPATH='#{@domain_home}/#{WLS_PRE_JARS_CACHE_DIR}/*'"
          wls_post_classpath = "export POST_CLASSPATH='#{@domain_home}/#{WLS_POST_JARS_CACHE_DIR}/*'"

          File.open(@application.root.to_s + '/' + SETUP_ENV_SCRIPT, 'a') do |f|

            f.puts '# 3. Add JVM Arguments by editing the startWebLogic.sh script                                                      '
            f.puts '# Export User defined memory, jvm settings, pre/post classpaths inside the startWebLogic.sh                        '
            f.puts '# Need to use \\" with sed to expand the environment variables                                                     '
            f.puts "sed -i.bak \"s#^DOMAIN_HOME#\\n#{wls_pre_classpath}\\n#{wls_post_classpath}\\n&#1\" #{@domain_home}/startWebLogic.sh"
            f.puts "sed -i.bak \"s#^DOMAIN_HOME#export USER_MEM_ARGS='${APP_ID_ARGS} #{@droplet.java_opts.join(' ')} '\\n&#1\" #{@domain_home}/startWebLogic.sh "
            f.puts '                                                                                                                   '
          end
        end

        # Modify the server name to include the instance index in the generated domain
        def rename_server_instance
          File.open(@application.root.to_s + '/' + SETUP_ENV_SCRIPT, 'a') do |f|
            f.puts '                                                                                                                   '
            f.puts '# 4. Server renaming using index to differentiate server instances                                                 '
            f.puts '                                                                                                                   '
            f.puts "SERVER_NAME_TAG=#{@server_name}                                                                                    "
            f.puts 'NEW_SERVER_NAME_TAG=${SERVER_NAME_TAG}-${INSTANCE_INDEX}                                                           '
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
