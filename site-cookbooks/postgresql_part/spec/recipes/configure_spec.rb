require_relative '../spec_helper'
require 'chefspec'

describe 'postgresql_part::configure' do
  let(:chef_run) { ChefSpec::SoloRunner.new }

  primary_hostname = 'primary'
  primary_ip = '172.0.0.10'
  standby_hostname = 'standby'
  standby_ip = '172.0.0.11'
  ap_ip = '172.0.0.1'
  generate_passwd = 'generete_rep_passwd'

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

    allow_any_instance_of(Chef::Recipe).to receive(:primary_db?).and_return(true)

    services = {
      'postgresql' => {
        ID: 'postgresql',
        Service: 'postgresql',
        Tags: nil,
        Address: '',
        Port: 5432
      }
    }

    allow_any_instance_of(Chef::Recipe)
      .to receive(:consul_service_info).with('postgresql').and_return(services)

    allow_any_instance_of(Chef::Recipe).to receive(:primary_db_ip).and_return(primary_ip)
    allow_any_instance_of(Chef::Recipe).to receive(:standby_db_ip).and_return(standby_ip)

    allow_any_instance_of(Chef::Recipe)
      .to receive(:generate_password).with('db_replication').and_return(generate_passwd)
    allow_any_instance_of(Chef::Resource)
      .to receive(:generate_password).with('db_replication').and_return(generate_passwd)
    allow_any_instance_of(Chef::Resource)
      .to receive(:generate_password).with('db_application').and_return(generate_passwd)
    allow_any_instance_of(Chef::Resource)
      .to receive(:generate_password).with('db_replication_check').and_return(generate_passwd)
    allow_any_instance_of(Chef::Resource)
      .to receive(:generate_password).with('tomcat').and_return(generate_passwd)

    chef_run.converge(described_recipe)

    allow(CloudConductor::ConsulClient::Catalog).to receive_message_chain(:service, :empty?).and_return(false)
    chef_run.converge(described_recipe)
  end

  it 'create pgpass' do
    pgpass = [{
      'ip' => '127.0.0.1',
      'port' => "#{chef_run.node['postgresql']['config']['port']}",
      'db_name' => 'replication',
      'user' => "#{chef_run.node['postgresql_part']['replication']['user']}",
      'passwd' => generate_passwd
    }, {
      'ip' => primary_ip,
      'port' => "#{chef_run.node['postgresql']['config']['port']}",
      'db_name' => 'replication',
      'user' => "#{chef_run.node['postgresql_part']['replication']['user']}",
      'passwd' => generate_passwd
    }, {
      'ip' => standby_ip,
      'port' => "#{chef_run.node['postgresql']['config']['port']}",
      'db_name' => 'replication',
      'user' => "#{chef_run.node['postgresql_part']['replication']['user']}",
      'passwd' => generate_passwd
    }]

    expect(chef_run).to create_template("#{chef_run.node['postgresql_part']['home_dir']}/.pgpass").with(
      source: 'pgpass.erb',
      mode: '0600',
      owner: 'postgres',
      group: 'postgres',
      variables: {
        pgpass: pgpass
      }
    )
  end

  describe 'this node is primary db' do
    it 'include primary recipe' do
      expect(chef_run).to include_recipe 'postgresql_part::configure_primary'
    end
  end

  describe 'this node is standby db' do
    before do
      allow_any_instance_of(Chef::Recipe).to receive(:primary_db?).and_return(false)
      chef_run.converge(described_recipe)
    end

    it 'include standby recipe' do
      expect(chef_run).to include_recipe 'postgresql_part::configure_standby'
    end
  end
end
