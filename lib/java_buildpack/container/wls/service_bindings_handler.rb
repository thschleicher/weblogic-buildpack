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

# rubocop:disable Metrics/ClassLength
module JavaBuildpack
  module Container
    module Wls

      # Handle Service Bindings
      class ServiceBindingsHandler

        # From a set of files
        def self.create_service_definitions_from_file_set(service_binding_locations, configRoot, output_props_file)

          service_binding_locations.each do |input_service_bindings_location|
          log_and_print("Processing Service Binding location: #{input_service_bindings_location}")

            parent_path_name = Pathname.new(File.dirname(input_service_bindings_location))
            module_name = parent_path_name.relative_path_from(configRoot).to_s.downcase

            input_service_bindings_file = File.open(input_service_bindings_location, 'r')
            service_config = YAML.load_file(input_service_bindings_file)

            service_config.each do |service_entry|
              create_service_definitions_from_app_config(service_entry, module_name, output_props_file)
            end
          end
        end

        # From bindings
        def self.create_service_definitions_from_bindings(service_config, output_props_file)
          service_config.each do |service_entry|
            puts "Service Entry: #{service_entry}"
            service_type = service_entry['label']
            log_and_print("Processing Service Binding of type: #{service_type} and definition : #{service_entry} ")

            if service_type[/(cleardb)|(elephantsql)|(oracle)|(postgres)|(mysql)|(mariadb)/i]
              create_jdbc_service_definition(service_entry, output_props_file)
            elsif service_type[/cloudamqp/i]
              save_amqp_jms_service_definition(service_entry, output_props_file)
            elsif service_type[/user-provided/]
              create_user_provided_service_definitions_from_bindings(service_entry, output_props_file)
            else
              log_and_print("Unknown Service bindings !!!... #{service_entry}")
            end
          end
        end

        # From user provided service bindings
        def self.create_user_provided_service_definitions_from_bindings(service_entry, output_props_file)
          user_defined_service = service_entry
          if user_defined_service.to_s[/jdbc/i]
            # This appears to be of type JDBC
            create_jdbc_service_definition(service_entry, output_props_file)
          elsif user_defined_service.to_s[/amqp/i]
            # This appears to be of type AMQP
            save_amqp_jms_service_definition(service_entry, output_props_file)
          elsif user_defined_service.to_s[/jmsServer/i]
            # This appears to be of type JMS Server & related destinations
            service_name = user_defined_service['name']
            service_name = 'JMS-' + service_name unless service_name[/^JMS/]
            save_from_user_defined_service_definition(user_defined_service, output_props_file, service_name)
          elsif user_defined_service.to_s[/jndiProperties/i]
            # This appears to be of type Foreign JMS Server & related destinations
            service_name = user_defined_service['name']
            service_name = 'ForeignJMS-' + service_name unless service_name[/^ForeignJMS/i]
            save_from_user_defined_service_definition(user_defined_service, output_props_file, service_name)
          else
            # This appears to be an unknown type of service - just convert to wlst properties type
            # and let the script figure out what to do
            log_and_print("Unknown User defined Service bindings !!!... #{user_defined_service}")
            service_name = user_defined_service['name']
            save_from_user_defined_service_definition(user_defined_service, output_props_file, service_name)
          end
        end

        # From application configuration
        def self.create_service_definitions_from_app_config(service_config, module_name, output_props_file)
          log_and_print("-----> Processing App bundled Service Definition : #{service_config}")

          service_name     = service_config[0]
          subsystem_config = service_config[1]

          if module_name == '.'
            # Directly save the Domain configuration
            save_base_service_definition(subsystem_config, output_props_file, 'Domain')
          elsif module_name[/jdbc/i]
            # Directly save the jdbc configuration
            save_jdbc_service_definition(subsystem_config, output_props_file)
          elsif module_name[/^jms/i]
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

        # JDBC connection retry frequency
        JDBC_CONN_CREATION_RETRY_FREQ_SECS = 900.freeze

        # JDBC bindings
        def self.create_jdbc_service_definition(service_entry, output_props_file)
          # p "Processing JDBC service entry: #{service_entry}"
          jdbc_datasource_config             = service_entry['credentials']
          jdbc_datasource_config['name']     = service_entry['name']
          jdbc_datasource_config['jndiName'] = service_entry['name'] unless jdbc_datasource_config['jndiName']

          save_jdbc_service_definition(jdbc_datasource_config, output_props_file)
        end

        def self.mysql?(jdbc_datasource_config)
          [/mysql/i, /mariadb/i].any? { |filter| matcher(jdbc_datasource_config, filter) }
        end

        def self.postgres?(jdbc_datasource_config)
          [/postgres/i, /elephantsql/i].any? { |filter| matcher(jdbc_datasource_config, filter) }
        end

        def self.oracle?(jdbc_datasource_config)
          [/oracle/i].any? { |filter| matcher(jdbc_datasource_config, filter) }
        end

        # Save the MySql JDBC attribute
        def self.save_mysql_attrib(f)
          f.puts 'driver=com.mysql.jdbc.Driver'
          f.puts 'testSql=SQL SELECT 1'
          f.puts 'xaProtocol=None'
        end

        # Save the Postgres JDBC attribute
        def self.save_postgres_attrib(f)
          f.puts 'driver=org.postgresql.Driver'
          f.puts 'testSql=SQL SELECT 1'
          f.puts 'xaProtocol=None'
        end

        # Save the Oracle JDBC attribute
        def self.save_oracle_attrib(jdbc_datasource_config, f)
          f.puts 'testSql=SQL SELECT 1 from DUAL'
          f.puts jdbc_datasource_config['driver'] ? "driver=#{jdbc_datasource_config['driver']}" : 'driver=oracle.jdbc.OracleDriver'

          xa_protocol = jdbc_datasource_config['xaProtocol']
          xa_protocol = 'None' unless xa_protocol
          f.puts "xaProtocol=#{xa_protocol}"
        end

        # Save the JDBC storage capacities
        def self.save_capacities(jdbc_datasource_config, f)
          init_capacity = jdbc_datasource_config['initCapacity']
          max_capacity = jdbc_datasource_config['maxCapacity']

          init_capacity = 1 unless init_capacity
          max_capacity = 4 unless max_capacity

          f.puts "initCapacity=#{init_capacity}"
          f.puts "maxCapacity=#{max_capacity}"
        end

        # Save the pool settings
        def self.save_pool_setting(jdbc_datasource_config, f)
          f.puts "name=#{jdbc_datasource_config['name']}"
          f.puts "jndiName=#{jdbc_datasource_config['jndiName']}"

          configure_jdbc_url(jdbc_datasource_config)

          if jdbc_datasource_config['isMultiDS']
            f.puts 'isMultiDS=true'
            f.puts "jdbcUrlPrefix=#{jdbc_datasource_config['jdbcUrlPrefix']}"
            f.puts "jdbcUrlEndpoints=#{jdbc_datasource_config['jdbcUrlEndpoints']}"
            f.puts "mp_algorithm=#{jdbc_datasource_config['mp_algorithm']}"
          else

            f.puts 'isMultiDS=false'
            f.puts "jdbcUrl=#{jdbc_datasource_config['jdbcUrl']}"
          end

          f.puts "username=#{jdbc_datasource_config['username']}" if jdbc_datasource_config['username']
          f.puts "password=#{jdbc_datasource_config['password']}" if jdbc_datasource_config['password']

        end

        # Configure the JDBC connection URL
        def self.configure_jdbc_url(jdbc_datasource_config)
          given_jdbc_url = jdbc_datasource_config['jdbcUrl']

          return if given_jdbc_url

          # If there are no jdbcUrl, then uri parameter is being used to pass in the Jdbc Url (as in managed services)

          given_jdbc_url = jdbc_datasource_config['uri']

          return unless given_jdbc_url

          # Sample uri can be: jdbc:oracle://test:9U6DFinHnqeI7_L@testoracle.testhost.com:1521/XE
          # Take out the credentials from within the uri and save those as user/password
          # Oracle JDBC Driver has issues with urls having //user:password@host format
          # Example: The driver oracle.jdbc.OracleDriver does not accept URL jdbc:oracle://test:9U6DFinHnqeI7_L@testoracle.testhost.com:1521/XE

          # First add 'jdbc'
          given_jdbc_url = "jdbc:#{given_jdbc_url}"

          if given_jdbc_url[/@/] && %r{//}.match(given_jdbc_url)
            start_index = given_jdbc_url.index('//') + 2
            end_index   = given_jdbc_url.index('@') - 1
            user_passwd_tokens = given_jdbc_url[start_index..end_index].split(':')

            # Move the indices either before or after the markers
            start_index -= 3
            end_index += 2

            uri = jdbc_datasource_config['uri']
            if uri[/^oracle/i]
              # Only newer oracle thin driver versions support jdbc:oracle:thin:@//hostname:port format,
              # Just go with @hostname... for now
              # jdbc_url = given_jdbc_url[0..start_index] + 'thin:@//' + given_jdbc_url[end_index..-1]
              jdbc_url = given_jdbc_url[0..start_index] + 'thin:@' + given_jdbc_url[end_index..-1]
            else
              # For all others like postgres/mysql, include the '//' as they support jdbc:postgresql://host:port/database
              jdbc_url = given_jdbc_url[0..(start_index + 2)] + given_jdbc_url[end_index..-1]
            end

            jdbc_datasource_config['username'] = user_passwd_tokens[0]
            jdbc_datasource_config['password'] = user_passwd_tokens[1]
          else
            jdbc_url = given_jdbc_url
          end

          # save the reconfigured jdbc url inside the map
          jdbc_datasource_config['jdbcUrl'] = jdbc_url
        end

        # Save the connection reset setting
        def self.save_connectionrefresh_setting(jdbc_datasource_config, f)
          connection_creation_retry_frequency = JDBC_CONN_CREATION_RETRY_FREQ_SECS
          connection_creation_retry_frequency = jdbc_datasource_config['connectionCreationRetryFrequency'] unless jdbc_datasource_config['connectionCreationRetryFrequency'].nil?
          f.puts "connectionCreationRetryFrequency=#{connection_creation_retry_frequency}"
        end

        # Save the other JDBC settings
        def self.save_other_jdbc_settings(jdbc_datasource_config, f)
          jdbc_datasource_config.each do |entry|
            # Save everything else that does not match the already saved patterns
            f.puts "#{entry[0]}=#{entry[1]}" unless entry[0][/(name)|(jndiName)|(password)|(isMulti)|(jdbcUrl)|(mp_algo)|(Capacity)|(connection)|(driver)|(testSql)|(xaProtocol)/]
          end

        end

        # Save the JDBC service definitions
        def self.save_jdbc_service_definition(jdbc_datasource_config, output_props_file)
          section_name = jdbc_datasource_config['name']
          section_name = 'JDBCDatasource-' + section_name unless section_name[/^JDBCDatasource/]
          log("Saving JDBC Datasource service defn : #{jdbc_datasource_config}")

          File.open(output_props_file, 'a') do |f|
            f.puts ''
            f.puts "[#{section_name}]"

            save_pool_setting(jdbc_datasource_config, f)
            save_capacities(jdbc_datasource_config, f)
            save_connectionrefresh_setting(jdbc_datasource_config, f)

            if mysql?(jdbc_datasource_config)
              save_mysql_attrib(f)
            elsif postgres?(jdbc_datasource_config)
              save_postgres_attrib(f)
            elsif oracle?(jdbc_datasource_config)
              save_oracle_attrib(jdbc_datasource_config, f)
            end

            save_other_jdbc_settings(jdbc_datasource_config, f)

            f.puts ''
          end
        end

        # Dont see a point of WLS customers using AMQP to communicate...
        def self.save_amqp_jms_service_definition(amqpService, output_props_file)

          # Dont know which InitialCF to use as well as the various arguments to pass in to bridge WLS To AMQP

          File.open(output_props_file, 'a') do |f|
            f.puts ''
            f.puts "[ForeignJMS-AQMP-#{amqpService['name']}]"
            f.puts "name=#{amqpService['name']}"
            f.puts 'jndiProperties=javax.naming.factory.initial=org.apache.qpid.amqp_1_0.jms.jndi.PropertiesFileInitialContextFactory;' + 'javax.naming.provider.url=' + "#{amqpService['credentials']['uri']}"
            f.puts ''

          end
        end

        # Save the definitions
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

        # Save the user defined definitions
        def self.save_from_user_defined_service_definition(service_config, output_props_file, service_name)
          # log("Saving from Yaml, Service Defn : #{service_config} with service_name: #{service_name}")
          File.open(output_props_file, 'a') do |f|
            f.puts ''
            f.puts "[#{service_name}]"

            service_config['credentials'].each do |entry|
              f.puts "#{entry[0]}=#{entry[1]}"
            end

            f.puts ''

          end
        end

        # Match the given JDBC Service against the filter
        def self.matcher(jdbc_service, filter)
          filter = Regexp.new(filter) unless filter.is_a?(Regexp)

          jdbc_service['name'] =~ filter || jdbc_service['label'] =~ filter   \
           || jdbc_service['driver'] =~ filter                                \
           || jdbc_service['jdbcUrl'] =~ filter                               \
           || jdbc_service['uri'] =~ filter                                   \
           || (jdbc_service['tags'].any? { |tag| tag =~ filter }  if jdbc_service['tags'])

        end

        # Log the message
        def self.log(content)
          JavaBuildpack::Container::Wls::WlsUtil.log(content)
        end

        # Log and print the message
        def self.log_and_print(content)
          JavaBuildpack::Container::Wls::WlsUtil.log_and_print(content)
        end
      end
    end
  end
end
