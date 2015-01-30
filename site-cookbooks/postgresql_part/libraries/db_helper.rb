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
::Chef::Recipe.send(:include, ConsulHelper)
module DbHelper
  def db_servers
    node['cloudconductor']['servers'].select { |_name, server| server['roles'].include?('db') }
  end
  
  def enable_db_names
    db_server_names = db_servers.keys
    db_server_names[0, 2]
  end
  
  def partner_db
    partner_db_name = enable_db_names.reject { |item|item == node[:hostname] }.first
    db_servers[partner_db_name]
  end
  
  def primary?
    helper = Chef::Recipe::Helper.new
    tag_possession_nodes = helper.find_node_possession_tag(service: 'db', tag: 'primary')
    if tag_possession_nodes.empty?
      db_servers[enable_db_names.first]['private_ip'] == node[:ipaddress] ? true : false
    else
      tag_possession_nodes.first['Address'] == node[:ipaddress] ? true : false
    end
  end
end
