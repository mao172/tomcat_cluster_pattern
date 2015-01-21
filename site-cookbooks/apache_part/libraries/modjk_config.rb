#
#
class Chef
  class Recipe
    #
    # this class is library definitions.
    # this is included in to apache_part cookbook.
    # it is a part of pattern for CloudConductor.
    class ModJkConfigure
      #
      # when using loadbalancer it return true as value.
      def self.using_loadbalancer(node)
        private_ip = node['ipaddress']

        result = true

        tomcat_servers = node['cloudconductor']['servers'].select { |_, s| s['roles'].include?('ap') }

        return result if tomcat_servers.empty?

        unless node['apache_part']['loadbalancer']
          target_sv = tomcat_servers.select { |_, s| s['private_ip'] == private_ip }

          result = false unless target_sv.empty?
        end

        result
      end

      #
      # when using loadbalancer it return 'loadbalancer' as value of String.
      # when unusing loadbalancer it return value is server-name
      # that included into cludconductor.servers attribute.
      # this returned server-name is matched to recipe running node private ip address.
      def self.worker_name(node)
        unless using_loadbalancer(node)
          private_ip = node['ipaddress']
          tomcat_servers = node['cloudconductor']['servers'].select { |_, s| s['roles'].include?('ap') }
          target_sv = tomcat_servers.select { |_, s| s['private_ip'] == private_ip }
          return target_sv.first.first
        end

        'loadbalancer'
      end
    end
  end
end
