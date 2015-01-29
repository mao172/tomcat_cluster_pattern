#
# Cookbook Name:: haproxy_part
# Library:: consul_helper
#
#

require 'rest-client'
require 'json'
require 'base64'

class Chef
  class Provider
    #
    #
    class ConsulUtils
      CONSUL_KVS_URL ||= 'http://127.0.0.1:8500/v1/kv/'

      #
      #
      def self.request_url(key)
        "#{CONSUL_KVS_URL}/#{key}"
      end

      #
      #
      def self.get_value(key, type)
        begin
          response = RestClient.get(request_url(key))
          res_hash = JSON.parse(response, symbolize_names: true).first
          value = Base64.decode64(res_hash[:Value])

          value = JSON.parse(value, symbolize_names: true) if type == :json
        rescue
          value = {} if type == :json
        end
        value
      end
    end
  end
end
