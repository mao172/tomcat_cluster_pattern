#
# Cookbook Name:: haproxy_part
# Library:: consul_helper
#
#

require 'json'
require 'base64'

class Chef
  class Provider
    #
    #
    class ConsulUtils
      #
      #
      def self.get_value(key, type)
        begin
          value = CloudConductor::ConsulClient::KeyValueStore.get(key)
          value = JSON.parse(value, symbolize_names: true) if type == :json
        rescue JSON::ParserError => e
          Chef::Log.warn "#{e.class} #{e.message}"
          value = {} if type == :json
        end
        value
      end
    end
  end
end
