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

      # Weblogic JVM helper
      class JvmArgHelper

        # Load the app bundled configurations and re-configure as needed the JVM parameters for the Server VM
        # @return [Hash] the configuration or an empty hash if the configuration file does not exist
        def self.update(java_opts)

          # Use JVM Args defaults
          jvm_default_map = {
            'min_perm_size'  => 128,
            'max_perm_size'  => 128,
            'min_heap_size'  => 512,
            'max_heap_size'  => 1024,
            'other_jvm_opts' => ' -verbose:gc -Xloggc:gc.log -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:-DisableExplicitGC -Djava.security.egd=file:/dev/./urandom '
          }

          java_opt_tokens = java_opts.join(' ').split

          java_opt_tokens.each do |token|

            int_value_in_mb = token[/[0-9]+/].to_i

            # The values incoming can be in MB or KB
            # Convert all to MB
            int_value_in_mb = (int_value_in_mb / 1_024) if token[/k$/i]

            if token[/-XX:PermSize/]
              jvm_default_map['min_perm_size'] = int_value_in_mb if int_value_in_mb > 128
            elsif token[/-XX:MaxPermSize/]
              jvm_default_map['max_perm_size'] = int_value_in_mb if int_value_in_mb > 128
            elsif token[/-Xms/]
              jvm_default_map['min_heap_size'] = int_value_in_mb
            elsif token[/-Xmx/]
              jvm_default_map['max_heap_size'] = int_value_in_mb
            else
              jvm_default_map['other_jvm_opts'] = jvm_default_map['other_jvm_opts'] + ' ' + token
            end
          end

          reset_java_opts java_opts, jvm_default_map
        end

        # Remove all Java Opts and reset with the ones provided
        def self.reset_java_opts(java_opts, jvm_default_map)
          java_opts.clear
          java_opts << "-Xms#{jvm_default_map['min_heap_size']}m"
          java_opts << "-Xmx#{jvm_default_map['max_heap_size']}m"
          java_opts << "-XX:PermSize=#{jvm_default_map['min_perm_size']}m"
          java_opts << "-XX:MaxPermSize=#{jvm_default_map['max_perm_size']}m"
          java_opts << jvm_default_map['other_jvm_opts']

          # Set the server listen port using the $PORT argument set by the warden container
          java_opts.add_system_property 'weblogic.ListenPort', '$PORT'
        end

        # Check whether to start in Wlx Mode that would disable JMS, EJB and JCA
        def self.add_wlx_server_mode(java_opts, start_in_wlx_mode)
          java_opts.add_system_property 'serverType', 'wlx' if start_in_wlx_mode
        end
      end
    end
  end
end
