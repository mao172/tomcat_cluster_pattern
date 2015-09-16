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
  def standby_db_ip
    if primary_db?(db_servers[0]['private_ip'])
      primary_private_ip(db_servers[1]['hostname'])
    else
      primary_private_ip(db_servers[0]['hostname'])
    end
  end

  def primary_db_ip
    if primary_db?(db_servers[0]['private_ip'])
      primary_private_ip(db_servers[0]['hostname'])
    else
      primary_private_ip(db_servers[1]['hostname'])
    end
  end

  def primary_db?(ip)
    catalog = CloudConductor::ConsulClient::Catalog
    primary_node = catalog.service('postgresql', tag: 'primary').sort do |node1, node2|
      node1['Address'] <=> node2['Address']
    end

    if primary_node.empty?
      first_db_server['private_ip'] == ip ? true : false
    else
      primary_node.first['Address'] == ip ? true : false
    end
  end

  def consul_service_info(service_id)
    CloudConductor::ConsulClient.services[service_id]
  end
end unless defined?(DbHelper)

Chef::Recipe.send(:include, DbHelper)
