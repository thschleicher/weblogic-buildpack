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

require 'java_buildpack/container'

require 'pathname'
require 'yaml'

module JavaBuildpack
  module Container
    module Wls

      class ServiceBindingsHandler

        def self.create_service_definitions_from_file_set(service_binding_locations, configRoot, output_props_file)

          service_binding_locations.each do |input_service_bindings_location|

            parent_path_name = Pathname.new(File.dirname(input_service_bindings_location))
            module_name = parent_path_name.relative_path_from(configRoot).to_s.downcase

            input_service_bindings_file = File.open(input_service_bindings_location, 'r')
            service_config = YAML.load_file(input_service_bindings_file)

            service_config.each do |service_entry|
              create_service_definitions_from_app_config(service_entry, module_name, output_props_file)
            end
          end
        end

        def self.create_service_definitions_from_bindings(service_config, output_props_file)

          service_config.each do |service_entry|

            service_type = service_entry['label']

            log_and_print("Processing Service Binding of type: #{service_type} and definition : #{service_entry} ")

            if service_type[/cleardb/]
              create_jdbc_service_definition(service_entry, output_props_file)
            elsif service_type[/elephantsql/]
              create_jdbc_service_definition(service_entry, output_props_file)
            elsif service_type[/cloudamqp/]
              save_amqp_jms_service_definition(service_entry, output_props_file)
            elsif service_type[/user-provided/]
              user_defined_service = service_entry
              if user_defined_service.to_s[/jdbc/]
                # This appears to be of type JDBC
                create_jdbc_service_definition(service_entry, output_props_file)
              elsif user_defined_service.to_s[/amqp/]
                # This appears to be of type AMQP
                save_amqp_jms_service_definition(service_entry, output_props_file)
              else
                log_and_print("Unknown User defined Service bindings !!!... #{user_defined_service}")
              end
            else
              log_and_print("Unknown Service bindings !!!... #{service_entry}")
            end
          end
        end

        def self.create_service_definitions_from_app_config(service_config, module_name, output_props_file)

          log_and_print("-----> Processing App bundled Service Definition : #{service_config}")

          service_name     = service_config[0]
          subsystem_config = service_config[1]

          if module_name == '.'
            # Directly save the Domain configuration
            save_base_service_definition(subsystem_config, output_props_file, 'Domain')
          elsif module_name[/jdbc/]
            # Directly save the jdbc configuration
            save_jdbc_service_definition(subsystem_config, output_props_file)
          elsif module_name[/^jms/]
            service_name = 'JMS-' + service_name unless service_name[/^JMS/]
            # Directly save the JMS configuration
            save_base_service_definition(subsystem_config, output_props_file, service_name)
          elsif module_name[/^foreign/]
            service_name = 'ForeignJMS-' + service_name unless service_name[/^ForeignJMS/]
            # Directly save the Foreign JMS configuration
            save_base_service_definition(subsystem_config, output_props_file, service_name)
          elsif module_name[/security/]
            # Directly save the Security configuration
            save_base_service_definition(subsystem_config, output_props_file, 'Security')
          else
            log_and_print("       Unknown subsystem, just saving it : #{subsystem_config}")
            # Dont know what subsystem this relates to, just save it as Section matching its service_name
            save_base_service_definition(subsystem_config, output_props_file, service_name)
          end
        end

        JDBC_CONN_CREATION_RETRY_FREQ_SECS = 900.freeze

        def self.create_jdbc_service_definition(service_entry, output_props_file)

          # p "Processing JDBC service entry: #{service_entry}"
          jdbc_datasource_config             = service_entry['credentials']
          jdbc_datasource_config['name']     = service_entry['name']
          jdbc_datasource_config['jndiName'] = service_entry['name'] unless jdbc_datasource_config['jndiName']

          save_jdbc_service_definition(jdbc_datasource_config, output_props_file)
        end

        def self.mysql?(jdbc_datasource_config)
          [/mysql/, /mariadb/].any? { |filter| matcher(jdbc_datasource_config, filter) }
        end

        def self.postgres?(jdbc_datasource_config)
          [/postgres/, /elephantsql/].any? { |filter| matcher(jdbc_datasource_config, filter) }
        end

        def self.oracle?(jdbc_datasource_config)
          [/oracle/].any? { |filter| matcher(jdbc_datasource_config, filter) }
        end

        def self.save_mysql_attrib(f)
          f.puts 'driver=com.mysql.jdbc.Driver'
          f.puts 'testSql=SQL SELECT 1'
          f.puts 'xaProtocol=None'
        end

        def self.save_postgres_attrib(f)
          f.puts 'driver=org.postgresql.Driver'
          f.puts 'testSql=SQL SELECT 1'
          f.puts 'xaProtocol=None'
        end

        def self.save_oracle_attrib(jdbc_datasource_config, f)
          f.puts 'testSql=SQL SELECT 1 from DUAL'
          f.puts jdbc_datasource_config['driver'] ? "driver=#{jdbc_datasource_config['driver']}" : 'driver=oracle.jdbc.OracleDriver'

          xa_protocol = jdbc_datasource_config['xaProtocol']
          xa_protocol = 'None' unless xa_protocol
          f.puts "xaProtocol=#{xa_protocol}"
        end

        def self.save_capacities(jdbc_datasource_config, f)
          init_capacity = jdbc_datasource_config['initCapacity']
          max_capacity = jdbc_datasource_config['maxCapacity']

          init_capacity = 1 unless init_capacity
          max_capacity = 4 unless max_capacity

          f.puts "initCapacity=#{init_capacity}"
          f.puts "maxCapacity=#{max_capacity}"
        end

        def self.save_multipool_setting(jdbc_datasource_config, f)

          jdbc_url = jdbc_datasource_config['jdbcUrl']
          # Check against postgres for jdbc_url,
          # it only passes in uri rather than jdbc_url
          jdbc_url = "jdbc:#{jdbc_datasource_config['uri']}" unless jdbc_url

          if jdbc_datasource_config['isMultiDS']
            f.puts 'isMultiDS=true'
            f.puts "jdbcUrlPrefix=#{jdbc_datasource_config['jdbcUrlPrefix']}"
            f.puts "jdbcUrlEndpoints=#{jdbc_datasource_config['jdbcUrlEndpoints']}"
            f.puts "mp_algorithm=#{jdbc_datasource_config['mp_algorithm']}"
          else
            f.puts 'isMultiDS=false'
            f.puts "jdbcUrl=#{jdbc_url}"
          end
        end

        def self.save_connectionrefresh_setting(jdbc_datasource_config, f)
          connection_creation_retry_frequency = JDBC_CONN_CREATION_RETRY_FREQ_SECS
          connection_creation_retry_frequency = jdbc_datasource_config['connectionCreationRetryFrequency'] unless jdbc_datasource_config['connectionCreationRetryFrequency'].nil?
          f.puts "connectionCreationRetryFrequency=#{connection_creation_retry_frequency}"
        end

        def self.save_credentials_setting(jdbc_datasource_config, f)
          f.puts "name=#{jdbc_datasource_config['name']}"
          f.puts "jndiName=#{jdbc_datasource_config['jndiName']}"
          f.puts "username=#{jdbc_datasource_config['username']}" if jdbc_datasource_config['username']
          f.puts "password=#{jdbc_datasource_config['password']}" if jdbc_datasource_config['password']
        end

        def self.save_jdbc_service_definition(jdbc_datasource_config, output_props_file)

          section_name = jdbc_datasource_config['name']
          section_name = 'JDBCDatasource-' + section_name unless section_name[/^JDBCDatasource/]
          log("Saving JDBC Datasource service defn : #{jdbc_datasource_config}")

          File.open(output_props_file, 'a') do |f|
            f.puts ''
            f.puts "[#{section_name}]"

            save_credentials_setting(jdbc_datasource_config, f)
            save_multipool_setting(jdbc_datasource_config, f)
            save_capacities(jdbc_datasource_config, f)
            save_connectionrefresh_setting(jdbc_datasource_config, f)

            if mysql?(jdbc_datasource_config)
              save_mysql_attrib(f)
            elsif postgres?(jdbc_datasource_config)
              save_postgres_attrib(f)
            elsif oracle?(jdbc_datasource_config)
              save_oracle_attrib(jdbc_datasource_config, f)
            end

            f.puts ''
          end
        end

        # Dont see a point of WLS customers using AMQP to communicate...
        def self.save_amqp_jms_service_definition(amqpService, output_props_file)

          # log("Saving AMQP service defn : #{amqpService}")

          # Dont know which InitialCF to use as well as the various arguments to pass in to bridge WLS To AMQP
          # Found some docs that talk of Apache ActiveMQ: org.apache.activemq.jndi.ActiveMQInitialContextFactory
          # and some others using: org.apache.qpid.amqp_1_0.jms.jndi.PropertiesFileInitialContextFactory

          File.open(output_props_file, 'a') do |f|
            f.puts ''
            f.puts "[ForeignJMS-AQMP-#{amqpService['name']}]"
            f.puts "name=#{amqpService['name']}"
            f.puts 'jndiProperties=javax.naming.factory.initial=org.apache.qpid.amqp_1_0.jms.jndi.PropertiesFileInitialContextFactory;' + 'javax.naming.provider.url=' + "#{amqpService['credentials']['uri']}"
            f.puts ''

          end
        end

        # Dont see a point of WLS customers using AMQP to communicate...
        def self.save_base_service_definition(service_config, output_props_file, service_name)
          # log("Saving Service Defn : #{service_config} with service_name: #{service_name}")
          File.open(output_props_file, 'a') do |f|
            f.puts ''
            f.puts "[#{service_name}]"

            service_config.each do |entry|
              f.puts "#{entry[0]}=#{entry[1]}"
            end

            f.puts ''

          end
        end

        def self.matcher(jdbc_service, filter)
          filter = Regexp.new(filter) unless filter.kind_of?(Regexp)

          jdbc_service['name'] =~ filter || jdbc_service['label'] =~ filter   \
           || jdbc_service['driver'] =~ filter                                \
           || jdbc_service['jdbcUrl'] =~ filter                               \
           || jdbc_service['uri'] =~ filter                                   \
           || (jdbc_service['tags'].any? { |tag| tag =~ filter }  if jdbc_service['tags'])

        end

        def self.log(content)
          JavaBuildpack::Container::Wls::WlsUtil.log(content)
        end

        def self.log_and_print(content)
          JavaBuildpack::Container::Wls::WlsUtil.log_and_print(content)
        end

      end
    end
  end
end
