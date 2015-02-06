#
# Cookbook Name:: apache_part
# Library:: modjk_helper
#
#

module ApachePart
  module ModJkHelper
    #
    # when using loadbalancer it return true as value.
    def enable_loadbalance?
      if node['apache_part']['loadbalancer'] || ap_servers.empty?
        true
      else
        local_ap_server ? false : true
      end
    end

    #
    # when using loadbalancer it return 'loadbalancer' as value of String.
    # when unusing loadbalancer it return value is server-name
    # that included into cludconductor.servers attribute.
    # this returned server-name is matched to recipe running node private ip address.
    def worker_name
      if enable_loadbalance?
        'loadbalancer'
      else
        local_ap_server.first
      end
    end

    private

    def ap_servers
      node['cloudconductor']['servers'].select { |_, s| s['roles'].include?('ap') }
    end

    def local_ap_server
      ap_servers.find { |_, s| s['private_ip'] == node['ipaddress'] }
    end
  end
end
