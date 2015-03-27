#
# Cookbook Name:: haproxy_part
# Spec:: Library:: consul_helpre

require_relative '../spec_helper'
require_relative '../../../cloudconductor/libraries/consul_helper.rb'
require_relative '../../../cloudconductor/libraries/consul_helper_kv.rb'
require_relative '../../libraries/consul_helper.rb'

describe Chef::Provider::ConsulUtils do
  key = 'haproxy_part/helper_test/key'
  value = 'haproxy_part::helper_test::value'

  before do
    @helper = Chef::Provider::ConsulUtils

    allow(CloudConductor::ConsulClient::KeyValueStore)
      .to receive(:get).with(key).and_return(value)

    allow(CloudConductor::ConsulClient::KeyValueStore)
      .to receive(:get).with('json_key').and_return('{"at1":"value01"}')

    allow(CloudConductor::ConsulClient::KeyValueStore)
      .to receive(:get).with('ssl_pem').and_return('')

    # CloudConductor::ConsulClient::KeyValueStore.put(key, value)
  end

  it '#get_value' do
    ret = @helper.get_value(key, :string)

    expect(ret).to eq(value)

    # CloudConductor::ConsulClient::KeyValueStore.delete(key)
  end

  it '#get_value with type: => :json' do
    ret = @helper.get_value('json_key', :json)

    result = {
      at1: 'value01'
    }

    expect(ret).to eq(result)

    # CloudConductor::ConsulClient::KeyValueStore.delete(key)
  end

  it '#get_value with key: => ssl_pem' do
    ret = @helper.get_value('ssl_pem', :string)

    expect(ret).to eq('')
  end
end
