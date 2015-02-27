#
# Spec:: Library:: consul_helpre_kv

require_relative '../spec_helper'
require_relative '../../libraries/consul_helper.rb'
require_relative '../../libraries/consul_helper_kv.rb'

describe CloudConductor::ConsulClient::KeyValueStore do
  before do
    @helper = CloudConductor
  end

  it 'put get delete' do
    key = 'consul_kvs_test_key'
    value = 'consul_kvs_test_value'

    @helper::ConsulClient::KeyValueStore.put(key, value)

    ret = @helper::ConsulClient::KeyValueStore.get(key)

    expect(ret).to eq(value)

    @helper::ConsulClient::KeyValueStore.delete(key)

    ret = @helper::ConsulClient::KeyValueStore.get(key)

    expect(ret).to eq('')
  end
end
