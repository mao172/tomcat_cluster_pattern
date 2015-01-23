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
require 'rest-client'
require 'json'

module ConsulHelper
  class Helper
    def add_service_tag(service_id, tag)
      agent = ConsulAgent.new
      service = agent.service(service_id)

      if service['Tags'].nil?
        service['Tags'] = [tag.to_s]
      elsif !service['Tags'].include?(tag)
        service['Tags'].push(tag)
      end

      service['Name'] = service['Service'].to_s

      agent.regist_service(service)
    end

    def service_deregist(args = {})
      fail ArgumentError unless args.key?(:Node) && args.key?(:ServiceID)

      catalog = ConsulCatalog.new
      catalog.deregister(args)
    end

    def find_other_service_node(service_id)
      agent = ConsulAgent.new
      my_name = agent.my_nodename
      catalog = ConsulCatalog.new
      service_nodes = catalog.service(service_id)
      service_nodes.delete_if { |item| item['Node'] == my_name }
    end

    def find_node_possession_tag(arg = {})
      catalog = ConsulCatalog.new
      service_nodes = catalog.service(arg[:service])
      service_nodes.delete_if { |item| item['ServiceTags'].nil? || !item['ServiceTags'].include?(arg[:tag]) }
    end
  end
  class ConsulAgent
    CONSUL_AGENT_URL = 'http://127.0.0.1:8500/v1/agent'
    CONSUL_AGENT_SERVICES_URL = "#{CONSUL_AGENT_URL}/services"
    CONSUL_AGENT_SERVICE_REGISTER_URL = "#{CONSUL_AGENT_URL}/service/register"
    CONSUL_AGENT_SELF_URL = "#{CONSUL_AGENT_URL}/self"

    def services
      begin
        response = JSON.parse(RestClient.get(CONSUL_AGENT_SERVICES_URL))
      rescue
        response = {}
      end
      response
    end

    def service(service_id)
      services = self.services

      fail "no regist service of #{service_id}" unless services.key?(service_id)

      services[service_id]
    end

    def regist_service(hash)
      RestClient.put(CONSUL_AGENT_SERVICE_REGISTER_URL, hash.to_json)
    end

    def self
      JSON.parse(RestClient.get(CONSUL_AGENT_SELF_URL))
    end

    def my_nodename
      self.self['Config']['NodeName']
    end
  end
  class ConsulCatalog
    CONSUL_CATALOG_URL = 'http://127.0.0.1:8500/v1/catalog'
    CONSUL_CATALOG_DEREGISTER_URL = "#{CONSUL_CATALOG_URL}/deregister"
    CONSUL_CATALOG_SERVICE_URL = "#{CONSUL_CATALOG_URL}/service"

    def deregister(hash)
      RestClient.put(CONSUL_CATALOG_DEREGISTER_URL, hash.to_json)
    end

    def service(service_id)
      fail ArgumentError if service_id.nil? || service_id.empty?
      begin
        response = JSON.parse(RestClient.get("#{CONSUL_CATALOG_SERVICE_URL}/#{service_id}"))
      rescue
        response = {}
      end

      response
    end
  end
end
