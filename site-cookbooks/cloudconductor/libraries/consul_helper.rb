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

require 'faraday'
require 'json'

module Consul
  class Service
    class << self
      def get(service_id, filters = {})
        request_url = "catalog/service/#{service_id}"
        filters = filters.select{ |key, value| %w(tag dc).include?(key) }
        unless filters.empty?
          request_url << '?' + filters.map{ |key, value| "#{key}=#{value}" }.join('&')
        end
        response = client.get(request_url)
        services = JSON.parse(response.body)
        services
      end

      private

      def client
        Faraday.new(url: 'http://localhost:8500/v1')
      end
    end
  end
end unless defined?(Consul)

Chef::Recipe.send(:include, Consul)
