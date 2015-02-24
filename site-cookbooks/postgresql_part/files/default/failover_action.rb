#!/usr/bin/env ruby
#

require 'faraday'
require 'json'

module CloudConductor
  class ConsulClient
    class << self
      def http
        Faraday.new(url: 'http://localhost:8500/v1', proxy: '')
      end
    end

    module Agent
      #
      # get services on local Consul agent
      #
      # endpoint: /v1/agent/services
      def services
        endpoint_url = 'agent/services'

        response = ConsulClient.http.get endpoint_url
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

        ConsulClient.http.put 'agent/service/register', json_data
      end

      def self.included(klass)
        klass.extend self
      end
    end

    include Agent
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
      if already?
        logger.info('this node is already primary.')
      else
        if system("sudo -u postgres pg_ctl promote -D #{ENV['PGSQL_DATA_DIR']}")
          logger.info('promoted to primary on successfully.')
          add_primary_tag
        else
          logger.error("failed to promote to primary. returns #{$CHILD_STATUS}")
        end
      end
    end

    private

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
      service_info = CloudConductor::ConsulClient.services['postgresql']

      service_info['Tags'] = [] if service_info['Tags'].nil?
      service_info['Tags'] << 'primary' unless service_info['Tags'].include? 'primary'

      CloudConductor::ConsulClient.regist_service('postgresql', service_info)

      service_config = CloudConductor::ConsulConfig.read('/etc/consul.d/postgresql.json')

      unless service_config['services'].nil?
        service_config['services']['tags'] = [] if service_config['services']['tags'].nil?
        service_config['services']['tags'] << 'primary' unless service_config['services']['tags'].include? 'primary'

        CloudConductor::ConsulConfig.write('/etc/consul.d/postgresql.json')
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  FailoverAction.execute
end
