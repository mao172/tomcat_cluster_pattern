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

describe ConsulHelper::Consul do
  describe '#services' do
    describe 'service registerd' do
      it 'return parsed services from consul' do
        response = '{"ap":{"ID":"ap","Service":"ap","Tags":null,"Port":8080}}'

        consul = ConsulHelper::Consul.new

        allow(RestClient).to receive(:get).with(ConsulHelper::Consul::CONSUL_AGENT_SERVICES_URL).and_return(response)

        expect(consul.services).to eq(JSON.parse(response))
      end
    end
    describe 'service not registerd' do
      it 'return empty hash' do
        allow(RestClient).to receive(:get).with(ConsulHelper::Consul::CONSUL_AGENT_SERVICES_URL).and_return('{}')

        consul = ConsulHelper::Consul.new
        expect(consul.services).to eq({})
      end
    end
  end

  describe '#service' do
    before do
      response = ['{"ap":{"ID":"ap","Service":"ap","Tags":null,"Port":8080},',
                  '"db":{"ID":"db","Service":"db","Tags":null,"Port":5432}}'].join
      allow(RestClient).to receive(:get).with(ConsulHelper::Consul::CONSUL_AGENT_SERVICES_URL).and_return(response)
    end

    describe 'id is a registerd service id' do
      it 'return service' do
        consul = ConsulHelper::Consul.new
        expect(consul.service('ap')).to eq(JSON.parse('{"ID":"ap","Service":"ap","Tags":null,"Port":8080}'))
      end
    end

    describe 'id is not registerd service id' do
      it 'raise error' do
        consul = ConsulHelper::Consul.new
        expect { consul.service('www') }.to raise_error('no regist service of www')
      end
    end

    describe 'service not registerd' do
      it 'raise error' do
        allow(RestClient).to receive(:get).with(ConsulHelper::Consul::CONSUL_AGENT_SERVICES_URL).and_return('{}')

        consul = ConsulHelper::Consul.new
        expect { consul.service('db') }.to raise_error('no regist service of db')
      end
    end
  end

  describe '#regist_service' do
    it 'register' do
      regist_hash = JSON.parse('{"ID":"ap","Name":"ap","Tags":"primary","Port":8080}')
      expect(RestClient).to receive(:put).with(ConsulHelper::Consul::CONSUL_AGENT_SERVICE_REGISTER_URL, regist_hash.to_json)

      consul = ConsulHelper::Consul.new
      consul.send(:regist_service, regist_hash)
    end
  end

  describe '#add_service_tag' do
    describe 'tag of resigerd service is nill' do
      it 'register add tag' do
        response = '{"ap":{"ID":"ap","Service":"ap","Tags":null,"Port":8080}}'
        regist_json = '{"ID":"ap","Service":"ap","Tags":["primary"],"Port":8080,"Name":"ap"}'

        allow(RestClient).to receive(:get).with(ConsulHelper::Consul::CONSUL_AGENT_SERVICES_URL).and_return(response)
        expect(RestClient).to receive(:put).with(ConsulHelper::Consul::CONSUL_AGENT_SERVICE_REGISTER_URL, regist_json)
        consul = ConsulHelper::Consul.new
        consul.send(:add_service_tag, 'ap', 'primary')
      end
    end

    describe 'tag is not included on registerd service' do
      it 'register add tag' do
        response = '{"ap":{"ID":"ap","Service":"ap","Tags":["primary", "backuped"],"Port":8080}}'
        regist_json = '{"ID":"ap","Service":"ap","Tags":["primary","backuped"],"Port":8080,"Name":"ap"}'

        allow(RestClient).to receive(:get).with(ConsulHelper::Consul::CONSUL_AGENT_SERVICES_URL).and_return(response)
        expect(RestClient).to receive(:put).with(ConsulHelper::Consul::CONSUL_AGENT_SERVICE_REGISTER_URL, regist_json)
        consul = ConsulHelper::Consul.new
        consul.send(:add_service_tag, 'ap', 'primary')
      end
    end

    describe 'tag is included on registerd service' do
      it 'register not changed tag' do
        response = '{"ap":{"ID":"ap","Service":"ap","Tags":["backuped"],"Port":8080}}'
        regist_json = '{"ID":"ap","Service":"ap","Tags":["backuped","primary"],"Port":8080,"Name":"ap"}'

        allow(RestClient).to receive(:get).with(ConsulHelper::Consul::CONSUL_AGENT_SERVICES_URL).and_return(response)
        expect(RestClient).to receive(:put).with(ConsulHelper::Consul::CONSUL_AGENT_SERVICE_REGISTER_URL, regist_json)
        consul = ConsulHelper::Consul.new
        consul.send(:add_service_tag, 'ap', 'primary')
      end
    end

    describe 'service id is not registerd' do
      it 'raise error' do
        allow(RestClient).to receive(:get).with(ConsulHelper::Consul::CONSUL_AGENT_SERVICES_URL).and_return('{}')

        consul = ConsulHelper::Consul.new
        expect { consul.service('db') }.to raise_error('no regist service of db')
      end
    end
  end
end
