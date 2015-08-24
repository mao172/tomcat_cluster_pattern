#
# Cookbook Name:: cloudconductor
# Library:: consul_helper_kv
#

require 'json'

module CloudConductor
  class ConsulClient
    class KeyValueStore
      class << self
        def put(key, value)
          value = JSON.generate(value) if value.is_a?(Hash)

          ConsulClient.http.put ConsulClient.request_url("kv/#{key}"), value
        end

        def get(key, _optional = nil)
          # puts "#{ConsulClient.request_url("kv/#{key}?raw")}"
          response = ConsulClient.http.get ConsulClient.request_url("kv/#{key}?raw")

          response.body
        end

        def keys(key)
          response = ConsulClient.http.get ConsulClient.request_url("kv/#{key}?keys")
          response.body
        end

        def delete(key)
          ConsulClient.http.delete ConsulClient.request_url("kv/#{key}")
        end
      end
    end unless defined? (KeyValueStore)
  end
end
