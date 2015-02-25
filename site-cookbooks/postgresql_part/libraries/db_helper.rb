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

module DbHelper
  def db_servers
    node['cloudconductor']['servers'].select { |_name, server| server['roles'].include?('db') }
  end

  def standby_db_ip
    first_node_ip = db_servers[db_servers.keys[0]]['private_ip']
    if primary_db?(first_node_ip)
      db_servers[db_servers.keys[1]]['private_ip']
    else
      first_node_ip
    end
  end

  def primary_db_ip
    node_ip = db_servers[db_servers.keys[0]]['private_ip']
    node_ip = db_servers[db_servers.keys[1]]['private_ip'] unless primary_db?(node_ip)
    node_ip
  end

  def primary_db?(ipaddress)
    catalog = CloudConductor::ConsulClient::Catalog
    primary_node = catalog.service('postgresql', tag: 'primary')

    if primary_node.empty?
      db_servers[db_servers.keys.first]['private_ip'] == ipaddress ? true : false
    else
      primary_node.first['Address'] == ipaddress ? true : false
    end
  end
end unless defined?(DbHelper)

Chef::Recipe.send(:include, DbHelper)
