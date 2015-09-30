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
require 'cgi'

module CloudConductor
  class ConsulClient
    class << self
      def http
        Faraday.new(url: 'http://localhost:8500/v1', proxy: '')
      end

      def secret_key
        ENV['CONSUL_SECRET_KEY']
      end

      def token
        CGI.escape(secret_key) unless secret_key.nil? || secret_key.empty?
      end

      def acl_token?
        if token.nil? || token.empty?
          false
        else
          true
        end
      end

      def request_url(url, params = nil)
        params = {} if params.nil?
        params[:token] = ConsulClient.token if ConsulClient.acl_token?

        unless params.empty?
          if url.include?('?')
            url << '&' + params.map { |key, value| "#{key}=#{value}" }.join('&')
          else
            url << '?' + params.map { |key, value| "#{key}=#{value}" }.join('&')
          end
        end

        url
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

          response = ConsulClient.http.get(ConsulClient.request_url(request_url, filters))
          JSON.parse(response.body)
        end
      end
    end
  end unless defined?(ConsulClient)
end # unless defined?(CloudConductor)

# Chef::Recipe.send(:include, Consul)
