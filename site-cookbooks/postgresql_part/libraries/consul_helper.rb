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
    def add_service_tag(args = {})
      agent = ConsulAgent.new
      service = agent.service(args[:service_id])

      if service['Tags'].nil?
        service['Tags'] = [args[:tag].to_s]
      elsif !service['Tags'].include?(args[:tag])
        service['Tags'].push(args[:tag])
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

    def find_node_possession_tag(args = {})
      catalog = ConsulCatalog.new
      service_nodes = catalog.service(args[:service])
      service_nodes.delete_if { |item| item['ServiceTags'].nil? || !item['ServiceTags'].include?(args[:tag]) }
    end
  end
  class ConsulAgent
    @consul_agent_url = 'http://127.0.0.1:8500/v1/agent'
    @consul_agent_services_url = "#{@consul_agent_url}/services"
    @consul_agent_service_register_url = "#{@consul_agent_url}/service/register"
    @consul_agent_self_url = "#{@consul_agent_url}/self"

    attr_reader :consul_agent_services_url,
                :consul_agent_service_register_url,
                :consul_agent_self_url

    def services
      begin
        response = JSON.parse(RestClient.get(@consul_agent_services_url))
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
      RestClient.put(@consul_agent_service_register_url, hash.to_json)
    end

    def self
      JSON.parse(RestClient.get(@consul_agent_self_url))
    end

    def my_nodename
      self.self['Config']['NodeName']
    end
  end
  class ConsulCatalog
    @consul_catalog_url = 'http://127.0.0.1:8500/v1/catalog'
    @consul_catalog_deregister_url = "#{@consul_catalog_url}/deregister"
    @consul_catalog_service_url = "#{@consul_catalog_url}/service"

    attr_reader :consul_catalog_deregister_url,
                :consul_catalog_service_url

    def deregister(hash)
      RestClient.put(@consul_catalog_deregister_url, hash.to_json)
    end

    def service(service_id)
      fail ArgumentError if service_id.nil? || service_id.empty?
      begin
        response = JSON.parse(RestClient.get("#{@consul_catalog_service_url}/#{service_id}"))
      rescue
        response = {}
      end

      response
    end
  end
end
