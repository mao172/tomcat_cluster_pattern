require_relative '../spec_helper'
require_relative '../../../cloudconductor/libraries/consul_helper.rb'
require_relative '../../../cloudconductor/libraries/consul_helper_kv.rb'
require 'chefspec'

describe 'postgresql_part::configure_standby' do
  let(:chef_run) { ChefSpec::SoloRunner.new }

  primary_hostname = 'primary'
  primary_ip = '172.0.0.10'
  standby_hostname = 'standby'
  standby_ip = '172.0.0.11'
  ap_ip = '172.0.0.1'
  # ap2_ip = '172.0.0.2'
  dba_passwd = 'dba_password'
  app_db = 'application_db'
  db_port = '5432'
  rep_user = 'replication_user'
  generate_rep_passwd = 'generete_rep_passwd'
  app_user = 'application_user'
  generate_app_passwd = 'generete_app_passwd'

  before do
    chef_run.node.set['postgresql']['version'] = '9.4'
    chef_run.node.set['postgresql']['config']['port'] = db_port
    chef_run.node.set['postgresql']['assign_postgres_password'] = true
    chef_run.node.set['postgresql']['password']['postgres'] = dba_passwd
    chef_run.node.set['postgresql_part']['replication']['user'] = rep_user
    chef_run.node.set['postgresql_part']['replication']['passwd'] = 'replication_pass'
    chef_run.node.set['postgresql_part']['replication']['replication_slot'] = 'chef_spec_slot'
    chef_run.node.set['postgresql_part']['application']['database'] = app_db
    chef_run.node.set['postgresql_part']['application']['user'] = app_user
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
    chef_run.node.automatic_attrs['hostname'] = primary_hostname
    chef_run.node.automatic_attrs['ipaddress'] = primary_ip

    allow_any_instance_of(Chef::Recipe).to receive(:primary_db?).and_return(false)
    allow_any_instance_of(Chef::Recipe).to receive(:standby_db_ip).and_return(standby_ip)

    allow(CloudConductor::ConsulClient::KeyValueStore).to receive(:keys).and_return('')

    chef_run.converge(described_recipe)

    allow_any_instance_of(Chef::Recipe)
      .to receive(:generate_password).with('db_replication').and_return(generate_rep_passwd)
    allow_any_instance_of(Chef::Resource)
      .to receive(:generate_password).with('db_replication').and_return(generate_rep_passwd)
    allow_any_instance_of(Chef::Resource)
      .to receive(:generate_password).with('db_application').and_return(generate_app_passwd)
    chef_run.converge(described_recipe)
  end

  describe 'this node is standby db' do
    before do
      allow_any_instance_of(Chef::Recipe).to receive(:primary_db?).and_return(false)

      chef_run.node.automatic_attrs['hostname'] = primary_hostname
      chef_run.node.automatic_attrs['ipaddress'] = primary_ip
      chef_run.node.set['cloudconductor']['servers'] = {
        standby_hostname => {
          roles: 'db',
          private_ip: standby_ip
        },
        primary_hostname => {
          roles: 'db',
          private_ip: primary_ip
        },
        ap_server: {
          roles: 'ap',
          private_ip: ap_ip
        }
      }
      chef_run.converge(described_recipe)
    end

    it 'stop postgresql' do
      expect(chef_run.ruby_block('stop_postgresql'))
        .to notify('service[postgresql]').to(:stop).immediately
    end

    it 'delete data directory' do
      expect(chef_run).to delete_directory("#{chef_run.node['postgresql']['dir']}").with(
        recursive: true
      )
    end

    it 'do pg_basebackup' do
      cmd_params = []
      cmd_params << '-D'
      cmd_params << "#{chef_run.node['postgresql']['dir']}"
      cmd_params << '--xlog'
      cmd_params << '--verbose'
      cmd_params << '-h'
      cmd_params << "#{primary_ip}"
      cmd_params << '-U'
      cmd_params << 'replication'

      cmd = "su - postgres -c '/usr/bin/pg_basebackup #{cmd_params.join(' ')}'"

      expect(chef_run).to run_bash('pg_basebackup').with(
        code: cmd
      )
    end

    it 'delete recovery.done' do
      expect(chef_run).to delete_file("#{chef_run.node['postgresql']['dir']}/recovery.done")
    end

    describe 'synchronous replication' do
      it 'create recovery.conf' do
        chef_run.node.set['postgresql']['config']['synchronous_commit'] = 'on'
        chef_run.node.set['postgresql_part']['replication']['application_name'] = 'application'
        chef_run.converge(described_recipe)

        primary_conninfo = ["host=#{primary_ip} port=#{chef_run.node['postgresql']['config']['port']} ",
                            "user=#{chef_run.node['postgresql_part']['replication']['user']} ",
                            "password=#{generate_rep_passwd} ",
                            "application_name=#{chef_run.node['postgresql_part']['replication']['application_name']}"].join

        expect(chef_run.node['postgresql_part']['recovery']['primary_conninfo']).to eq(primary_conninfo)
        expect(chef_run.node['postgresql_part']['recovery']['primary_slot_name'])
          .to eq(chef_run.node['postgresql_part']['replication']['replication_slot'])

        expect(chef_run).to create_template("#{chef_run.node['postgresql']['dir']}/recovery.conf").with(
          source: 'recovery.conf.erb',
          mode: '0644',
          owner: 'postgres',
          group: 'postgres'
        )
      end
    end
    describe 'asynchronous replication' do
      it 'create recovery.conf' do
        chef_run.node.set['postgresql']['config']['synchronous_commit'] = 'off'
        chef_run.converge(described_recipe)

        primary_conninfo = ["host=#{primary_ip} port=#{chef_run.node['postgresql']['config']['port']} ",
                            "user=#{chef_run.node['postgresql_part']['replication']['user']} ",
                            "password=#{generate_rep_passwd}"].join

        expect(chef_run.node['postgresql_part']['recovery']['primary_conninfo']).to eq(primary_conninfo)
        expect(chef_run.node['postgresql_part']['recovery']['primary_slot_name'])
          .to eq(chef_run.node['postgresql_part']['replication']['replication_slot'])

        expect(chef_run).to create_template("#{chef_run.node['postgresql']['dir']}/recovery.conf").with(
          source: 'recovery.conf.erb',
          mode: '0644',
          owner: 'postgres',
          group: 'postgres'
        )
      end
    end

    it 'restart posgresql service' do
      service_name = 'postgresql'
      chef_run.node.set['postgresql']['server']['service_name'] = service_name
      chef_run.converge(described_recipe)

      service = chef_run.service('postgresql')
      expect(service).to do_nothing
      expect(service.service_name).to eq(service_name)
      expect(chef_run.template("#{chef_run.node['postgresql']['dir']}/recovery.conf"))
        .to notify('service[postgresql]').to(:start).delayed
    end
  end
end
