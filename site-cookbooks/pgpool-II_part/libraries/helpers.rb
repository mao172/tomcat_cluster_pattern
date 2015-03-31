#
# Cookbook Name:: pgpool-II_part
# Library:: helpers
#
#

require 'timeout'
require 'mixlib/shellout'

class Pgpool2Part
  module Helpers
    def servers(role)
      node['cloudconductor']['servers'].select { |_name, server| server['roles'].include?(role) }
    end

    def conf(key)
      node['pgpool_part'][key]
    end

    def wait_unless_completed_primary
      Timeout.timeout(conf('wait_timeout')) do
        while CloudConductor::ConsulClient::Catalog.service('postgresql', tag: 'primary').empty?
          puts 'waiting for primary ...'
          sleep conf('wait_interval')
        end
      end
    end

    def exec_command(cmd)
      context = Mixlib::ShellOut.new(cmd)
      context.run_command
      context.error? == false
    end

    def wait_unless_completed_database
      port = conf('postgresql')['port']

      Timeout.timeout(conf('wait_timeout')) do
        servers('db').each do |_name, server|
          until exec_command("hping3 -S #{server[:private_ip]} -p #{port} -c 5 | grep 'sport=#{port} flags=SA'")
            puts "... waiting for completed database (#{server[:private_ip]}:#{port}) ..."
            sleep conf('wait_interval')
          end
        end
      end
    end

    def backend_hostname(index)
      conf('pgconf')["backend_hostname#{index}"]
    end

    def pgpool_service
      resources('service[pgpool]')
    end

    def backend_status_check(index)
      params = []
      params << '0'
      params << 'localhost'
      params << '9898'
      params << conf('user')
      params << generate_password('pcp')

      while exec_command("pcp_node_info --verbose #{params.join(' ')} #{index} | grep -E 'Status *: +[0]' ")
        puts "... #{backend_hostname(index)} is during the initialization ..."
        exec_command("pcp_attach_node #{params.join(' ')} #{index}")
        pgpool_service.run_action(:restart)
        sleep conf('wait_interval')
      end
    end

    def wait_until_attached_to_backend
      Timeout.timeout(conf('wait_timeout')) do
        backend_status_check(0)
        backend_status_check(1)
      end
    end
  end
end
