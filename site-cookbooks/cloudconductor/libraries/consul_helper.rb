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

module CloudConductor
  class ConsulClient
    class << self
      def http
        Faraday.new(url: 'http://localhost:8500/v1', proxy: '')
      end
    end
    #
    # FullName:: CloudConductor::ConsulClient::Catalog
    class Catalog
      class << self
        #
        # service_id - String
        # filters    - Hash (optional)
        #              :service_id - String (optional)
        #              :dc - String (optional)
        #              :tag - String (optional)
        def service(service_id, filters = {})
          if service_id.is_a?(Hash)
            filters = service_id
            service_id = filters[:service_id]
          end

          request_url = "catalog/service/#{service_id}"
          filters = filters.select { |key, _value| %w(tag dc).include?(key.to_s) }
          unless filters.empty?
            request_url << '?' + filters.map { |key, value| "#{key}=#{value}" }.join('&')
          end

          response = ConsulClient.http.get(request_url)
          JSON.parse(response.body)
        end
      end
    end
  end unless defined?(ConsulClient)
end # unless defined?(CloudConductor)

# Chef::Recipe.send(:include, Consul)
