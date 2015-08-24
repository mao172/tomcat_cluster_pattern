#
# Spec:: Library:: consul_helpre_kv

require_relative '../spec_helper'
require_relative '../../libraries/consul_helper.rb'
require_relative '../../libraries/consul_helper_kv.rb'

describe CloudConductor::ConsulClient::KeyValueStore do
  token = '++token_key++'
  key = 'consul_kvs_test_key'
  value = 'consul_kvs_test_value'

  before do
    @helper = CloudConductor
    @client = CloudConductor::ConsulClient
    allow(@client).to receive_message_chain(:token).and_return(token)
  end

  it 'put' do
    allow(@client).to receive_message_chain(:http, :put)
      .with(:no_args)
      .with("kv/#{key}?token=++token_key++", value)
      .and_return('dummy')

    expect(@helper::ConsulClient::KeyValueStore.put(key, value)).to eq('dummy')
  end

  it 'delete' do
    allow(@client).to receive_message_chain(:http, :delete)
      .with(:no_args)
      .with("kv/#{key}?token=++token_key++")
      .and_return('dummy')

    expect(@helper::ConsulClient::KeyValueStore.delete(key)).to eq('dummy')
  end

  it 'get' do
    response_body = 'dummy'
    response = Faraday::Response
    allow(response).to receive(:body).and_return(response_body)

    allow(@client).to receive_message_chain(:http, :get)
      .with(:no_args)
      .with("kv/#{key}?raw&token=++token_key++")
      .and_return(response)

    expect(@helper::ConsulClient::KeyValueStore.get(key)).to eq(response_body)
  end

  it 'keys' do
    response_body = 'dummy'
    response = Faraday::Response
    allow(response).to receive(:body).and_return(response_body)

    allow(@client).to receive_message_chain(:http, :get)
      .with(:no_args)
      .with("kv/#{key}?keys&token=++token_key++")
      .and_return(response)

    expect(@helper::ConsulClient::KeyValueStore.keys(key)).to eq(response_body)
  end
end
