# -*- coding: utf-8 -*-
#
# Cookbook Name:: CloudConductor
# Library:: consul_helper_agent
#
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
#
#

require 'faraday'
require 'json'

module CloudConductor
  class ConsulClient
    module Agent
      #
      # get services on local Consul agent
      #
      # endpoint: /v1/agent/services
      def services
        endpoint_url = 'agent/services'

        response = ConsulClient.http.get ConsulClient.request_url(endpoint_url)
        result = JSON.parse(response.body)
        result = {} if result.nil?
        result
      end

      #
      # regist service to local Consul agent
      #
      # name    - String as service name.
      #
      # options - Hash (optional)
      #           :id    - String
      #           :name  - String
      #           :port  - Fixnum (optional) default 0
      #           :tags  - Array (optional)
      #           :check - Hash (optional)
      #
      # endpoint:: /v1/agent/service/regist
      def regist_service(name, options = nil)
        if name.is_a? Hash
          options = name
          # name = options[:name]
        else
          options = {} if options.nil?
          options[:name] = name
        end

        json_data = JSON.generate(options)

        # puts json_data

        ConsulClient.http.put ConsulClient.request_url('agent/service/register'), json_data
      end

      def remove_service(service_id)
        ConsulClient.http.put ConsulClient.request_url("agent/service/deregister/#{service_id}")
      end

      def self.included(klass)
        klass.extend self
      end
    end

    include Agent
  end
end # unless defined? (CloudConductor)
