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
      module WlsConstants

        NEWLINE              = "\n".freeze

        APP_NAME             = 'ROOT'.freeze
        WEB_INF_DIRECTORY    = 'WEB-INF'.freeze

        JAVA_BINARY          = 'java'.freeze
        SERVER_VM            = '-server'.freeze
        CLIENT_VM            = '-client'.freeze

        SETUP_ENV_SCRIPT     = 'setupEnv.sh'.freeze
        WLS_CONFIGURE_SCRIPT = 'configure.sh'.freeze

        # Prefer App Bundled Config or Buildpack bundled Config
        PREFER_APP_CONFIG    = 'prefer_app_config'.freeze

        # Prefer App Bundled Config or Buildpack bundled Config
        START_IN_WLX_MODE    = 'start_in_wlx_mode'.freeze

        # Parent Location to save/store the application during deployment
        DOMAIN_APPS_FOLDER   = 'apps'.freeze

        # WLS_DOMAIN_PATH is relative to sandbox
        WLS_DOMAIN_PATH      = 'domains/'.freeze

        # Required during Install...
        # Files required for installing from a jar in silent mode
        ORA_INSTALL_INVENTORY_FILE = 'oraInst.loc'.freeze
        WLS_INSTALL_RESPONSE_FILE  = 'installResponseFile'.freeze

        # keyword to change to point to actual wlsInstall in response file
        WLS_INSTALL_PATH_TEMPLATE  = 'WEBLOGIC_INSTALL_PATH'.freeze
        WLS_ORA_INVENTORY_TEMPLATE = 'ORACLE_INVENTORY_INSTALL_PATH'.freeze
        WLS_ORA_INV_INSTALL_PATH   = '/tmp/wlsOraInstallInventory'.freeze

        BEA_HOME_TEMPLATE          = 'BEA_HOME="\$MW_HOME"'
        MW_HOME_TEMPLATE           = 'MW_HOME="\$MW_HOME"'

        # Expect to see a '.wls' folder containing domain configurations and script to create the domain within the App bits
        APP_WLS_CONFIG_CACHE_DIR   = '.wls'.freeze

        # Following are relative to the .wls folder all under the APP ROOT
        WLS_PRE_JARS_CACHE_DIR     = 'preJars'.freeze
        WLS_POST_JARS_CACHE_DIR    = 'postJars'.freeze

        WLS_JMS_CONFIG_DIR         = 'jms'.freeze
        WLS_JDBC_CONFIG_DIR        = 'jdbc'.freeze
        WLS_FOREIGN_JMS_CONFIG_DIR = 'foreignjms'.freeze

        # Following are relative to the .wls folder all under the APP ROOT
        WLS_SCRIPT_CACHE_DIR       = 'script'.freeze

        # Default WebLogic Configurations packaged within the buildpack
        BUILDPACK_CONFIG_CACHE_DIR = Pathname.new(File.expand_path('../../../../resources/wls', File.dirname(__FILE__))).freeze

      end
    end
  end
end
