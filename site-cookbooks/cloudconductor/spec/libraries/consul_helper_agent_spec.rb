require_relative '../spec_helper'
require_relative '../../libraries/consul_helper.rb'
require_relative '../../libraries/consul_helper_agent.rb'

describe CloudConductor do
  before do
    # @helper = Object.new
    @helper = CloudConductor
  end

  describe '::ConsulClient' do
    it 'service regist simple' do
      @helper::ConsulClient.regist_service('db')

      ret = @helper::ConsulClient.services['db']

      param = {
        'ID' => 'db',
        'Service' => 'db',
        'Tags' => nil,
        'Address' => '',
        'Port' => 0
      }

      expect(ret).to eq(param)
    end

    it 'service regist with id' do
      @helper::ConsulClient.regist_service('db', id: 'db1')

      ret = @helper::ConsulClient.services['db1']

      param = {
        'ID' => 'db1',
        'Service' => 'db',
        'Tags' => nil,
        'Address' => '',
        'Port' => 0
      }

      expect(ret).to eq(param)

      @helper::ConsulClient.remove_service('db1')

      expect(@helper::ConsulClient.services['db1']).to eq(nil)
    end

    it 'service regist with tags' do
      @helper::ConsulClient.regist_service('db', id: 'db2', tags: %w(hoge fuga))

      ret = @helper::ConsulClient.services['db2']

      param = {
        'ID' => 'db2',
        'Service' => 'db',
        'Tags' => %w(hoge fuga),
        'Address' => '',
        'Port' => 0
      }

      expect(ret).to eq(param)

      @helper::ConsulClient.remove_service('db2')

      expect(@helper::ConsulClient.services['db2']).to eq(nil)
    end

    it 'service regist from hash' do
      @helper::ConsulClient.regist_service(name: 'db', port: 5432)

      ret = @helper::ConsulClient.services['db']

      param = {
        'ID' => 'db',
        'Service' => 'db',
        'Tags' => nil,
        'Address' => '',
        'Port' => 5432
      }

      expect(ret).to eq(param)
    end

    it 'service regist from hash with tags' do
      @helper::ConsulClient.regist_service(id: 'db3', name: 'db', port: 5432, tags: %w(a b))

      ret = @helper::ConsulClient.services['db3']

      param = {
        'ID' => 'db3',
        'Service' => 'db',
        'Tags' => %w(a b),
        'Address' => '',
        'Port' => 5432
      }

      expect(ret).to eq(param)

      @helper::ConsulClient.remove_service('db3')

      expect(@helper::ConsulClient.services['db3']).to eq(nil)
    end

    it 'changed tags' do
      @helper::ConsulClient.regist_service('db')

      ret = @helper::ConsulClient.services['db']

      ret['Tags'] = [] if ret['Tags'].nil?
      ret['Tags'] << 'primary'
      name = ret['Service']

      @helper::ConsulClient.regist_service(name, ret)

      ret = @helper::ConsulClient.services['db']

      param = {
        'ID' => 'db',
        'Service' => 'db',
        'Tags' => %w(primary),
        'Address' => '',
        'Port' => 0
      }

      expect(ret).to eq(param)

      @helper::ConsulClient.remove_service('db')

      expect(@helper::ConsulClient.services['db']).to eq(nil)
    end

    describe 'service remove' do
      before do
        @helper::ConsulClient.regist_service(id: 'db', name: 'db')
        # @helper::ConsulClient.regist_service(id: 'db1', name: 'db')
        # @helper::ConsulClient.regist_service(id: 'db2', name: 'db')
        # @helper::ConsulClient.regist_service(id: 'db3', name: 'db')
      end

      it 'test' do
        @helper::ConsulClient.remove_service('db')

        expect(@helper::ConsulClient.services['db']).to eq(nil)
      end
    end
  end
end
