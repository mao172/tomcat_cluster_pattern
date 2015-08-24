# -*- coding: utf-8 -*-
# Copyright 2014 TIS Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'chef/recipe'
require 'chef/resource'
require 'chef/provider'

module CloudConductor
  module Helper
    def generate_password(key = '')
      OpenSSL::Digest::SHA256.hexdigest(node['cloudconductor']['salt'] + key)
    end

    def keys(prefix)
      data = CloudConductor::ConsulClient::KeyValueStore.keys(prefix)
      keys = JSON.parse(data) if data && data.length > 0
      keys
    end

    def load_network_config
      networks = {}

      prefix = 'cloudconductor/networks'

      keys(prefix).each do |key|
        next if key == prefix

        hostname = key.slice(%r{#{prefix}/(?<hostname>[^/]*)}, 'hostname')
        next if hostname == 'base'

        ifname = key.slice(%r{#{prefix}/#{hostname}/(?<ifname>[^/]*)}, 'ifname')
        next if ifname == 'vna'

        data = CloudConductor::ConsulClient::KeyValueStore.get(key)

        networks[hostname] ||= {}
        networks[hostname][ifname] = JSON.parse(data) if data && data.length > 0
      end if keys(prefix)

      networks
    end

    def primary_private_ip(hostname)
      return nil unless node['cloudconductor']['servers'][hostname]

      node.set['cloudconductor']['networks'] = load_network_config unless node['cloudconductor']['networks']

      if node['cloudconductor']['networks'] && node['cloudconductor']['networks'][hostname]
        node['cloudconductor']['networks'][hostname][node['cloudconductor']['networks'][hostname].keys.first]['virtual_address']
      else
        return node['cloudconductor']['servers'][hostname]['private_ip']
      end
    end

    def pick_servers_as_role(role)
      if node['cloudconductor'] && node['cloudconductor']['servers']
        servers = node['cloudconductor']['servers'].to_hash.select do |_, s|
          s['roles'].include?(role)
        end
        result = servers.map do |hostname, server_info|
          server_info['hostname'] = hostname
          server_info
        end
      else
        result = {}
      end
      result
    end

    def ap_servers
      pick_servers_as_role('ap')
    end

    def db_servers
      pick_servers_as_role('db')
    end

    def first_ap_server
      ap_servers.first
    end

    def first_db_server
      db_servers.first
    end
  end unless defined?(Helper)
end # unless defined?(CloudConductor)

Chef::Recipe.send(:include, CloudConductor::Helper)
Chef::Resource.send(:include, CloudConductor::Helper)
