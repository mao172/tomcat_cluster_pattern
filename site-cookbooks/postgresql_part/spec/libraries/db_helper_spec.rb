require_relative '../spec_helper'
require_relative '../../../cloudconductor/libraries/consul_helper'
require_relative '../../../cloudconductor/libraries/helper'
require_relative '../../libraries/db_helper'

describe 'DbHelper' do
  describe '#db_servers' do
    before do
      @helper = Object.new
      @helper.extend DbHelper
      @helper.extend CloudConductor::Helper
      node = { 'cloudconductor' => { 'servers' => { 'db' => { 'roles' => 'db' }, 'ab' => { 'roles' => 'ap' } } } }
      allow(@helper).to receive(:node).and_return(node)
    end

    it 'return db role hash' do
      expect(@helper.db_servers).to eq([{ 'roles' => 'db', 'hostname' => 'db' }])
    end
  end
  describe '#standby_db_ip' do
    before do
      @helper = Object.new
      @helper.extend DbHelper
      @helper.extend CloudConductor::Helper
      node = {
        'cloudconductor' => {
          'servers' => {
            'db1' => { 'roles' => 'db', 'private_ip' => '127.0.0.1' },
            'db2' => { 'roles' => 'db', 'private_ip' => '127.0.0.2' },
            'ap' => { 'roles' => 'ap' }
          }
        }
      }
      allow(@helper).to receive(:node).and_return(node)
    end
    describe 'if 1st hash of db_servers is the primary db' do
      before do
        allow(@helper).to receive(:primary_db?).and_return(true)
      end
      it 'return 2nd hash private_ip of db_servers' do
        expect(@helper.standby_db_ip).to eq('127.0.0.2')
      end
    end
    describe 'if first hash of db_servers is not the primary db' do
      before do
        allow(@helper).to receive(:primary_db?).and_return(false)
      end
      it 'return 1st hash private_ip of db_servers' do
        expect(@helper.standby_db_ip).to eq('127.0.0.1')
      end
    end
  end
  describe '#primary_db?' do
    before do
      @helper = Object.new
      @helper.extend DbHelper
      @helper.extend CloudConductor::Helper
      node = {
        'cloudconductor' => {
          'servers' => {
            'db1' => { 'roles' => 'db', 'private_ip' => '127.0.0.1' },
            'db2' => { 'roles' => 'db', 'private_ip' => '127.0.0.111' }
          }
        }
      }
      allow(@helper).to receive(:node).and_return(node)
    end
    describe 'if found at the consul' do
      before do
        allow(CloudConductor::ConsulClient::Catalog).to receive(:service).and_return([{ 'Address' => '127.0.0.1' }])
      end
      describe 'and registerd private_ip is same as the argument' do
        it 'return true' do
          node = @helper.db_servers[0]
          expect(@helper.primary_db?(node)).to eq(true)
        end
      end
      describe 'and registerd private_ip is different as the argument' do
        it 'return false' do
          node = @helper.db_servers[1]
          expect(@helper.primary_db?(node)).to eq(false)
        end
      end
    end
    describe 'if not found at the consul' do
      before do
        allow(CloudConductor::ConsulClient::Catalog).to receive(:service).and_return([])
      end
      describe 'and first node private_ip of db_servers is same as the argument' do
        it 'return true' do
          node = @helper.db_servers[0]
          expect(@helper.primary_db?(node)).to eq(true)
        end
      end
      describe 'and first node private_ip of db_servers is diffeerent as the argument' do
        it 'return false' do
          node = @helper.db_servers[1]
          expect(@helper.primary_db?(node)).to eq(false)
        end
      end
    end
  end
end
