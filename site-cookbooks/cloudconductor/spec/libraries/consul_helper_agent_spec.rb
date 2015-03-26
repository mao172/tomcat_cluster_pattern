require_relative '../spec_helper'
require_relative '../../libraries/consul_helper.rb'
require_relative '../../libraries/consul_helper_agent.rb'

describe CloudConductor do
  token = '++token_key++'

  before do
    # @helper = Object.new
    @helper = CloudConductor
  end

  describe '::ConsulClient' do
    before do
      @client = CloudConductor::ConsulClient
      allow(@client).to receive_message_chain(:token).and_return(token)
    end

    it 'service regist simple' do
      option = {}
      option[:name] = 'db'
      json = JSON.generate(option)

      allow(@client).to receive_message_chain(:http, :put)
        .with(:no_args)
        .with("agent/service/register?token=++token_key++", json)
        .and_return('dummy')

      expect(@client.regist_service('db')).to eq('dummy')
    end

    it 'service regist with id' do
      option = {id: 'db1'}
      option[:name] = 'db'
      json = JSON.generate(option)

      allow(@client).to receive_message_chain(:http, :put)
        .with(:no_args)
        .with("agent/service/register?token=++token_key++", json)
        .and_return('dummy')

      expect(@client.regist_service('db', id:'db1')).to eq('dummy')
    end

    it 'service regist with tags' do
      option = {id: 'db2', tags: %w(hoge fuga)}
      option[:name] = 'db'
      json = JSON.generate(option)

      allow(@client).to receive_message_chain(:http, :put)
        .with(:no_args)
        .with("agent/service/register?token=++token_key++", json)
        .and_return('dummy')
      expect(@client.regist_service('db', id:'db2', tags: %w(hoge fuga))).to eq('dummy')
    end

    it 'service regist from hash' do
      option = {name: 'db', port: 5432}
      json = JSON.generate(option)

      allow(@client).to receive_message_chain(:http, :put)
        .with(:no_args)
        .with("agent/service/register?token=++token_key++", json)
        .and_return('dummy')
      expect(@client.regist_service(name: 'db', port:5432)).to eq('dummy')
    end

    it 'service regist from hash with tags' do
      option = {id: 'db3', name: 'db', port: 5432, tags: %w(a b)}
      json = JSON.generate(option)

      allow(@client).to receive_message_chain(:http, :put)
        .with(:no_args)
        .with("agent/service/register?token=++token_key++", json)
        .and_return('dummy')
      expect(@client.regist_service(id: 'db3', name: 'db', port: 5432, tags: %w(a b))).to eq('dummy')
    end

    describe 'service remove' do
      it 'test' do
        allow(@client).to receive_message_chain(:http, :put)
          .with(:no_args)
          .with("agent/service/deregister/db?token=++token_key++")
          .and_return('dummy')

        expect(@helper::ConsulClient.remove_service('db')).to eq('dummy')
      end
    end
  end
end
