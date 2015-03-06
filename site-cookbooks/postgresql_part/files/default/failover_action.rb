#!/usr/bin/env ruby
#

require 'logger'
require 'faraday'
require 'json'
require 'cgi'

module CloudConductor
  class ConsulClient
    class << self
      def http
        Faraday.new(url: 'http://localhost:8500/v1', proxy: '')
      end

      def token
        CGI::escape("#{ENV['CONSUL_SECRET_KEY']}")
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
        else
          options = {} if options.nil?
          options[:name] = name
        end

        json_data = JSON.generate(options)

        ConsulClient.http.put ConsulClient.request_url('agent/service/register'), json_data
      end

      def self.included(klass)
        klass.extend self
      end
    end

    include Agent

    #
    # FullName:: CloudConductor::ConsulClient::Catalog
    class Catalog
      class << self
        def regist(data)
          data = JSON.generate(data) if data.is_a?(Hash)
          response = ConsulClient.http.put(ConsulClient.request_url("catalog/register"), data)
          puts "#{response.status}"
        end
        #
        # service_id - String
        # params     - Hash (optional)
        #              :service_id - String (optional)
        #              :dc - String (optional)
        #              :tag - String (optional)
        def service(service_id, params = nil)
          if service_id.is_a?(Hash)
            params = service_id
            service_id = params[:service_id]
          end

          request_url = "catalog/service/#{service_id}"

          params = {} if params.nil?
          params = params.select { |key, _value| %w(tag dc).include?(key.to_s) }

          response = ConsulClient.http.get(ConsulClient.request_url(request_url, params))
          JSON.parse(response.body)
        end

        def node(node_name)
          request_url = "catalog/node/#{node_name}"

          response = ConsulClient.http.get(ConsulClient.request_url(request_url))
          JSON.parse(response.body)
        end
      end
    end

    class KeyValueStore
      class << self
        def put(key, value)
          if value.is_a?(Hash)
            value = JSON.generate(value)
          end

          ConsulClient.http.put ConsulClient.request_url("kv/#{key}"), value
        end

        def get(key, _optional = nil)
          response = ConsulClient.http.get ConsulClient.request_url("kv/#{key}?raw")

          response.body
        end

        def delete(key)
          response = ConsulClient.http.delete ConsulClient.request_url("kv/#{key}")
          puts "#{response.status}"
        end
      end
    end
  end

  class ConsulConfig
    class << self
      def read(path)
        data = IO.read(path)
        JSON.parse(data)
      end

      def write(path, content)
        if content.is_a?(String)
          data = content
        else
          data = JSON.generate(content)
        end

        IO.write(path, data)
      end
    end
  end
end

class FailoverAction
  class << self
    def execute
      if lock?
        promote
        lock_free
      else
        logger.warn('failed to lock acquisition.')
      end
    end

    private

    def lock?
      value = CloudConductor::ConsulClient::KeyValueStore.get('cloudconductor/postgresql/failover-event/lock')

      logger.info("#{value}")
      if 'true' == value
        false
      else
        CloudConductor::ConsulClient::KeyValueStore.put('cloudconductor/postgresql/failover-event/lock', 'true')
        true
      end
    end

    def lock_free
      CloudConductor::ConsulClient::KeyValueStore.delete('cloudconductor/postgresql/failover-event/lock')
    end

    def promote
      if already?
        logger.info('this node is already primary.')
      else
        if system('service postgresql-9.4 promote')
          logger.info('promoted to primary on successfully.')
          add_primary_tag
        else
          logger.error("failed to promote to primary. returns #{$CHILD_STATUS}")
        end
      end
    end

    def root_dir
      '/opt/cloudconductor'
    end

    def init_logger
      log_file = File.join(root_dir, 'logs', 'failover_event_handler.log')
      logger = Logger.new(log_file)
      logger.formatter = proc do |severity, datetime, _progname, message|
        "[#{datetime.strftime('%Y-%m-%dT%H:%M:%S')}] #{severity}: #{message}\n"
      end
      logger
    end

    def logger
      @logger ||= init_logger
    end

    def already?
      service_info = CloudConductor::ConsulClient.services['postgresql']

      ret = false
      unless service_info['Tags'].nil?
        ret = true if service_info['Tags'].include? 'primary'
      end

      ret
    end

    def add_primary_tag
      remove_primary_tag

      service_info = CloudConductor::ConsulClient.services['postgresql']

      service_info['Tags'] = [] if service_info['Tags'].nil?
      service_info['Tags'] << 'primary' unless service_info['Tags'].include? 'primary'

      CloudConductor::ConsulClient.regist_service('postgresql', service_info)

      service_config = CloudConductor::ConsulConfig.read('/etc/consul.d/postgresql.json')

      unless service_config['service'].nil?
        service_config['service']['tags'] = [] if service_config['service']['tags'].nil?
        service_config['service']['tags'] << 'primary' unless service_config['service']['tags'].include? 'primary'

        CloudConductor::ConsulConfig.write('/etc/consul.d/postgresql.json', service_config)
      end
    end

    def remove_primary_tag
      primary_svr = CloudConductor::ConsulClient::Catalog.service('postgresql', tag: 'primary')

      logger.warn('primary database node is not one!') if primary_svr.size > 1
      logger.warn('primary database node is not found!') if primary_svr.size <= 0

      if primary_svr.size == 1
        primary_svr = primary_svr.first

        puts "primary => #{primary_svr}"

        node_name = primary_svr['Node']

        catalog_node_info = CloudConductor::ConsulClient::Catalog.node(node_name)

        puts "node => #{catalog_node_info}"

        data = {}
        data = data.merge(catalog_node_info["Node"])
        data["Service"] = catalog_node_info["Services"]["postgresql"]

        data["Service"]["Tags"] = data["Service"]["Tags"] - ['primary']

        CloudConductor::ConsulClient::Catalog.regist(data)
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  FailoverAction.execute
end
