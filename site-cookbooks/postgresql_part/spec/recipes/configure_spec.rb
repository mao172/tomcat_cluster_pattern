require_relative '../spec_helper'
require 'chefspec'

describe 'postgresql_part::configure' do
  let(:chef_run) { ChefSpec::SoloRunner.new }

  primary_hostname = 'primary'
  primary_ip = '172.0.0.10'
  standby_hostname = 'standby'
  standby_ip = '172.0.0.11'
  ap_ip = '172.0.0.1'

  before do
    chef_run.node.set['cloudconductor']['servers'] = {
      primary_hostname => {
        roles: 'db',
        private_ip: primary_ip
      },
      standby_hostname => {
        roles: 'db',
        private_ip: standby_ip
      },
      ap_server: {
        roles: 'ap',
        private_ip: ap_ip
      }
    }

    chef_run.converge(described_recipe)
  end

  describe 'this node is primary db' do

    before do
      allow_any_instance_of(Chef::Recipe).to receive(:is_primary_db?).and_return(true)
      chef_run.converge(described_recipe)
    end

    it 'include primary recipe' do
      expect(chef_run).to include_recipe 'postgresql_part::configure_primary'
    end
  end

  describe 'this node is standby db' do
    before do
      allow_any_instance_of(Chef::Recipe).to receive(:is_primary_db?).and_return(false)
      chef_run.converge(described_recipe)
    end

    it 'include standby recipe' do
      expect(chef_run).to include_recipe 'postgresql_part::configure_standby'
    end
  end
end

