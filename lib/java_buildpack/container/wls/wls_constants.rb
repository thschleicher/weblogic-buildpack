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

module JavaBuildpack
  module Container
    module Wls

      # Collection of constants used by the Weblogic container
      module WlsConstants

        # New line character
        NEWLINE              = "\n".freeze
        # Application web-inf directory name
        WEB_INF_DIRECTORY    = 'WEB-INF'.freeze
        # Java binary to execute
        JAVA_BINARY          = 'java'.freeze
        # Server option name
        SERVER_VM            = '-server'.freeze
        # Client option name
        CLIENT_VM            = '-client'.freeze

        # Name of the Weblogic configuration script
        WLS_CONFIGURE_SCRIPT = 'configure.sh'.freeze

        # Prefer App Bundled Config or Buildpack bundled Config
        PREFER_APP_CONFIG    = 'prefer_app_config'.freeze

        # Prefer App Bundled Config or Buildpack bundled Config
        START_IN_WLX_MODE    = 'start_in_wlx_mode'.freeze

        # Parent Location to save/store the application during deployment
        DOMAIN_APPS_FOLDER   = 'apps'.freeze

        # WLS_DOMAIN_PATH is relative to sandbox
        WLS_DOMAIN_PATH      = 'domains/'.freeze

        # Expect to see a '.wls' folder containing domain configurations and script to create the domain within the App bits
        APP_WLS_CONFIG_CACHE_DIR   = '.wls'.freeze

        # Relative to the .wls folder all under the APP ROOT
        WLS_PRE_JARS_CACHE_DIR     = 'preJars'.freeze
        # Relative to the .wls folder all under the APP ROOT
        WLS_POST_JARS_CACHE_DIR    = 'postJars'.freeze

        # JMS directory
        WLS_JMS_CONFIG_DIR         = 'jms'.freeze
        # JDBC directory
        WLS_JDBC_CONFIG_DIR        = 'jdbc'.freeze
        # Foreign JMS Directory
        WLS_FOREIGN_JMS_CONFIG_DIR = 'foreignjms'.freeze

        # Following are relative to the .wls folder all under the APP ROOT
        WLS_SCRIPT_CACHE_DIR       = 'script'.freeze

        # Default WebLogic Configurations packaged within the buildpack
        BUILDPACK_CONFIG_CACHE_DIR = Pathname.new(File.expand_path('../../../../resources/wls', File.dirname(__FILE__))).freeze

      end
    end
  end
end
