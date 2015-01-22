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
require_relative '../../libraries/consul_helper.rb'
require 'json'

describe ConsulHelper::ConsulAgent do
  describe '#services' do
    describe 'service registerd' do
      it 'return parsed services from consul' do
        response = '{"ap":{"ID":"ap","Service":"ap","Tags":null,"Port":8080}}'

        consul = ConsulHelper::ConsulAgent.new

        allow(RestClient).to receive(:get).with(ConsulHelper::ConsulAgent::CONSUL_AGENT_SERVICES_URL).and_return(response)

        expect(consul.services).to eq(JSON.parse(response))
      end
    end
    describe 'service not registerd' do
      it 'return empty hash' do
        allow(RestClient).to receive(:get).with(ConsulHelper::ConsulAgent::CONSUL_AGENT_SERVICES_URL).and_return('{}')

        consul = ConsulHelper::ConsulAgent.new
        expect(consul.services).to eq({})
      end
    end
  end

  describe '#service' do
    before do
      response = ['{"ap":{"ID":"ap","Service":"ap","Tags":null,"Port":8080},',
                  '"db":{"ID":"db","Service":"db","Tags":null,"Port":5432}}'].join
      allow(RestClient).to receive(:get).with(ConsulHelper::ConsulAgent::CONSUL_AGENT_SERVICES_URL).and_return(response)
    end

    describe 'id is a registerd service id' do
      it 'return service' do
        consul = ConsulHelper::ConsulAgent.new
        expect(consul.service('ap')).to eq(JSON.parse('{"ID":"ap","Service":"ap","Tags":null,"Port":8080}'))
      end
    end

    describe 'id is not registerd service id' do
      it 'raise error' do
        consul = ConsulHelper::ConsulAgent.new
        expect { consul.service('www') }.to raise_error('no regist service of www')
      end
    end

    describe 'service not registerd' do
      it 'raise error' do
        allow(RestClient).to receive(:get).with(ConsulHelper::ConsulAgent::CONSUL_AGENT_SERVICES_URL).and_return('{}')

        consul = ConsulHelper::ConsulAgent.new
        expect { consul.service('db') }.to raise_error('no regist service of db')
      end
    end
  end

  describe '#regist_service' do
    it 'register' do
      regist_hash = JSON.parse('{"ID":"ap","Name":"ap","Tags":"primary","Port":8080}')
      expect(RestClient).to receive(:put).with(ConsulHelper::ConsulAgent::CONSUL_AGENT_SERVICE_REGISTER_URL, regist_hash.to_json)

      consul = ConsulHelper::ConsulAgent.new
      consul.send(:regist_service, regist_hash)
    end
  end

  describe '#add_service_tag' do
    describe 'tag of resigerd service is nill' do
      it 'register add tag' do
        response = '{"ap":{"ID":"ap","Service":"ap","Tags":null,"Port":8080}}'
        regist_json = '{"ID":"ap","Service":"ap","Tags":["primary"],"Port":8080,"Name":"ap"}'

        allow(RestClient).to receive(:get).with(ConsulHelper::ConsulAgent::CONSUL_AGENT_SERVICES_URL).and_return(response)
        expect(RestClient).to receive(:put).with(ConsulHelper::ConsulAgent::CONSUL_AGENT_SERVICE_REGISTER_URL, regist_json)
        consul = ConsulHelper::ConsulAgent.new
        consul.send(:add_service_tag, 'ap', 'primary')
      end
    end

    describe 'tag is not included on registerd service' do
      it 'register add tag' do
        response = '{"ap":{"ID":"ap","Service":"ap","Tags":["primary", "backuped"],"Port":8080}}'
        regist_json = '{"ID":"ap","Service":"ap","Tags":["primary","backuped"],"Port":8080,"Name":"ap"}'

        allow(RestClient).to receive(:get).with(ConsulHelper::ConsulAgent::CONSUL_AGENT_SERVICES_URL).and_return(response)
        expect(RestClient).to receive(:put).with(ConsulHelper::ConsulAgent::CONSUL_AGENT_SERVICE_REGISTER_URL, regist_json)
        consul = ConsulHelper::ConsulAgent.new
        consul.send(:add_service_tag, 'ap', 'primary')
      end
    end

    describe 'tag is included on registerd service' do
      it 'register not changed tag' do
        response = '{"ap":{"ID":"ap","Service":"ap","Tags":["backuped"],"Port":8080}}'
        regist_json = '{"ID":"ap","Service":"ap","Tags":["backuped","primary"],"Port":8080,"Name":"ap"}'

        allow(RestClient).to receive(:get).with(ConsulHelper::ConsulAgent::CONSUL_AGENT_SERVICES_URL).and_return(response)
        expect(RestClient).to receive(:put).with(ConsulHelper::ConsulAgent::CONSUL_AGENT_SERVICE_REGISTER_URL, regist_json)
        consul = ConsulHelper::ConsulAgent.new
        consul.send(:add_service_tag, 'ap', 'primary')
      end
    end

    describe 'service id is not registerd' do
      it 'raise error' do
        allow(RestClient).to receive(:get).with(ConsulHelper::ConsulAgent::CONSUL_AGENT_SERVICES_URL).and_return('{}')

        consul = ConsulHelper::ConsulAgent.new
        expect { consul.service('db') }.to raise_error('no regist service of db')
      end
    end
  end
end
describe ConsulHelper::ConsulCatalog do
  describe '#deregister' do
    it 'put json to deregister api' do
      regist_hash = JSON.parse('{"Node":"node_name","ServiceID":"service_id"}')
      expect(RestClient).to receive(:put).with(ConsulHelper::ConsulCatalog::CONSUL_CATALOG_DEREGISTER_URL, regist_hash.to_json)

      catalog = ConsulHelper::ConsulCatalog.new
      catalog.send(:deregister, regist_hash)
    end
  end
  describe '#service_deregist' do
    describe 'received deregist service, node and datacenter' do
      it 'call deregister method and send to hash' do
        catalog = ConsulHelper::ConsulCatalog.new
        expect(catalog).to receive(:deregister).with(Datacenter: 'datacenter', Node: 'node_name', ServiceID: 'service_id')
        catalog.send(:service_deregist, Datacenter: 'datacenter', Node: 'node_name', ServiceID: 'service_id')
      end
    end
    describe 'received deregist service and node' do
      it 'call deregister method and send to hash' do
        catalog = ConsulHelper::ConsulCatalog.new
        expect(catalog).to receive(:deregister).with(Node: 'node_name', ServiceID: 'service_id')
        catalog.send(:service_deregist, Node: 'node_name', ServiceID: 'service_id')
      end
    end
    describe 'received deregist service only' do
      it 'raise error' do
        catalog = ConsulHelper::ConsulCatalog.new
        expect { catalog.service_deregist(service: 'service_id') }.to raise_error(ArgumentError)
      end
    end
    describe 'received deregist node only' do
      it 'raise error' do
        catalog = ConsulHelper::ConsulCatalog.new
        expect { catalog.service_deregist(Node: 'node_name') }.to raise_error(ArgumentError)
      end
    end
  end
end
