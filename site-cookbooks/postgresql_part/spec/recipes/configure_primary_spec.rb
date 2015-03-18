require_relative '../spec_helper'
require 'chefspec'

describe 'postgresql_part::configure_primary' do
  let(:chef_run) { ChefSpec::SoloRunner.new }

  myself_hostname = 'myself'
  myself_ip = '172.0.0.10'
  partner_hostname = 'partner'
  partner_ip = '172.0.0.11'
  ap_ip = '172.0.0.1'
  ap2_ip = '172.0.0.2'
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
      myself_hostname => {
        roles: 'db',
        private_ip: myself_ip
      },
      partner_hostname => {
        roles: 'db',
        private_ip: partner_ip
      },
      ap_server: {
        roles: 'ap',
        private_ip: ap_ip
      }
    }
    chef_run.node.automatic_attrs['hostname'] = myself_hostname
    chef_run.node.automatic_attrs['ipaddress'] = myself_ip

    allow_any_instance_of(Chef::Recipe).to receive(:primary_db?).and_return(true)
    allow_any_instance_of(Chef::Recipe).to receive(:standby_db_ip).and_return(partner_ip)

    service_info = {
      'ID' => 'postgresql',
      'Service' => 'postgresql',
      'Tags' => nil,
      'Address' => '',
      'Port' => 5432
    }

    allow_any_instance_of(Chef::Recipe)
      .to receive(:consul_service_info).with('postgresql').and_return(service_info)

    chef_run.converge(described_recipe)

    allow_any_instance_of(Chef::Recipe)
      .to receive(:generate_password).with('db_replication').and_return(generate_rep_passwd)
    allow_any_instance_of(Chef::Resource)
      .to receive(:generate_password).with('db_replication').and_return(generate_rep_passwd)
    allow_any_instance_of(Chef::Resource)
      .to receive(:generate_password).with('db_replication_check').and_return(generate_rep_passwd)
    allow_any_instance_of(Chef::Resource)
      .to receive(:generate_password).with('db_application').and_return(generate_app_passwd)

    allow_any_instance_of(Chef::Resource)
      .to receive(:generate_password).with('tomcat').and_return(generate_app_passwd)

    chef_run.converge(described_recipe)
  end

  describe 'this node is primary db' do
    postgresql_connection_info = {
      host: '127.0.0.1',
      port: db_port,
      username: 'postgres',
      password: dba_passwd
    }

    before do
      chef_run.node.automatic_attrs['hostname'] = myself_hostname
      chef_run.node.automatic_attrs['ipaddress'] = myself_ip
      chef_run.node.set['cloudconductor']['servers'] = {
        myself_hostname => {
          roles: 'db',
          private_ip: myself_ip
        },
        partner_hostname => {
          roles: 'db',
          private_ip: partner_ip
        },
        ap_server: {
          roles: 'ap',
          private_ip: ap_ip
        }
      }
      chef_run.converge(described_recipe)
    end

    it 'create pg_hba.conf' do
      pg_hda = [
        { 'type' => 'local', 'db' => 'all', 'user' => 'postgres', 'addr' => nil, 'method' => 'ident' },
        { 'type' => 'local', 'db' => 'all', 'user' => 'all', 'addr' => nil, 'method' => 'ident' },
        { 'type' => 'host', 'db' => 'all', 'user' => 'all', 'addr' => '127.0.0.1/32', 'method' => 'md5' },
        { 'type' => 'host', 'db' => 'all', 'user' => 'all', 'addr' => '::1/128', 'method' => 'md5' },
        { 'type' => 'host', 'db' => 'all', 'user' => 'postgres', 'addr' => '0.0.0.0/0', 'method' => 'reject' },
        {
          'type' => 'host', 'db' => 'replication', 'user' => "#{chef_run.node['postgresql_part']['replication']['user']}",
          'addr' => "#{myself_ip}/32", 'method' => 'md5'
        },
        {
          'type' => 'host', 'db' => 'replication', 'user' => "#{chef_run.node['postgresql_part']['replication']['user']}",
          'addr' => "#{partner_ip}/32", 'method' => 'md5'
        },
        { 'type' => 'host', 'db' => 'all', 'user' => 'all', 'addr' => "#{ap_ip}/32", 'method' => 'md5' }
      ]

      expect(chef_run).to create_template("#{chef_run.node['postgresql']['dir']}/pg_hba.conf").with(
        source: 'pg_hba.conf.erb',
        mode: '0644',
        owner: 'postgres',
        group: 'postgres',
        variables: {
          pg_hba: pg_hda
        }
      )
    end

    describe 'application server has more than' do
      before do
        chef_run.node.automatic_attrs['hostname'] = myself_hostname
        chef_run.node.set['cloudconductor']['servers'] = {
          myself_hostname => {
            roles: 'db',
            private_ip: myself_ip
          },
          partner_hostname => {
            roles: 'db',
            private_ip: partner_ip
          },
          ap_server: {
            roles: 'ap',
            private_ip: ap_ip
          },
          ap_server2: {
            roles: 'ap',
            private_ip: ap2_ip
          }
        }
        chef_run.converge(described_recipe)
      end

      it 'create pg_hba.conf' do
        pg_hda = [
          { 'type' => 'local', 'db' => 'all', 'user' => 'postgres', 'addr' => nil, 'method' => 'ident' },
          { 'type' => 'local', 'db' => 'all', 'user' => 'all', 'addr' => nil, 'method' => 'ident' },
          { 'type' => 'host', 'db' => 'all', 'user' => 'all', 'addr' => '127.0.0.1/32', 'method' => 'md5' },
          { 'type' => 'host', 'db' => 'all', 'user' => 'all', 'addr' => '::1/128', 'method' => 'md5' },
          { 'type' => 'host', 'db' => 'all', 'user' => 'postgres', 'addr' => '0.0.0.0/0', 'method' => 'reject' },
          {
            'type' => 'host', 'db' => 'replication', 'user' => "#{chef_run.node['postgresql_part']['replication']['user']}",
            'addr' => "#{myself_ip}/32", 'method' => 'md5'
          },
          {
            'type' => 'host', 'db' => 'replication', 'user' => "#{chef_run.node['postgresql_part']['replication']['user']}",
            'addr' => "#{partner_ip}/32", 'method' => 'md5'
          },
          { 'type' => 'host', 'db' => 'all', 'user' => 'all', 'addr' => "#{ap_ip}/32", 'method' => 'md5' },
          { 'type' => 'host', 'db' => 'all', 'user' => 'all', 'addr' => "#{ap2_ip}/32", 'method' => 'md5' }
        ]

        expect(chef_run).to create_template("#{chef_run.node['postgresql']['dir']}/pg_hba.conf").with(
          source: 'pg_hba.conf.erb',
          mode: '0644',
          owner: 'postgres',
          group: 'postgres',
          variables: {
            pg_hba: pg_hda
          }
        )
      end
    end

    it 'create replication user' do
      expect(chef_run).to ChefSpec::Matchers::ResourceMatcher.new(
        :postgresql_database_user,
        :create,
        rep_user
      ).with(
        connection: postgresql_connection_info,
        password: generate_rep_passwd,
        replication: true
      )
    end

    it 'create application db user' do
      expect(chef_run).to ChefSpec::Matchers::ResourceMatcher.new(
        :postgresql_database_user,
        :create,
        app_user
      ).with(
        connection: postgresql_connection_info,
        password: generate_app_passwd
      )
    end

    it 'create application database' do
      expect(chef_run).to ChefSpec::Matchers::ResourceMatcher.new(
        :postgresql_database,
        :create,
        app_db
      ).with(
        connection: postgresql_connection_info,
        owner: app_user
      )
    end

    describe 'synchronous replication' do
      it 'create recovery.done' do
        chef_run.node.set['postgresql']['config']['synchronous_commit'] = 'on'
        chef_run.converge(described_recipe)

        primary_conninfo =  ["host=#{partner_ip} port=#{chef_run.node['postgresql']['config']['port']} ",
                             "user=#{chef_run.node['postgresql_part']['replication']['user']} ",
                             "password=#{generate_rep_passwd} ",
                             "application_name=#{chef_run.node['postgresql_part']['replication']['application_name']}"].join

        expect(chef_run.node['postgresql_part']['recovery']['primary_conninfo']).to eq(primary_conninfo)
        expect(chef_run.node['postgresql_part']['recovery']['primary_slot_name'])
          .to eq(chef_run.node['postgresql_part']['replication']['replication_slot'])

        expect(chef_run).to create_template("#{chef_run.node['postgresql']['dir']}/recovery.done").with(
          source: 'recovery.conf.erb',
          mode: '0644',
          owner: 'postgres',
          group: 'postgres'
        )
      end
    end

    describe 'asynchronous replication' do
      it 'create recovery.done' do
        chef_run.node.set['postgresql']['config']['synchronous_commit'] = 'off'
        chef_run.node.set['postgresql_part']['replication']['application_name'] = 'application'
        chef_run.converge(described_recipe)

        primary_conninfo =  ["host=#{partner_ip} port=#{chef_run.node['postgresql']['config']['port']} ",
                             "user=#{chef_run.node['postgresql_part']['replication']['user']} ",
                             "password=#{generate_rep_passwd}"].join

        expect(chef_run.node['postgresql_part']['recovery']['primary_conninfo']).to eq(primary_conninfo)
        expect(chef_run.node['postgresql_part']['recovery']['primary_slot_name'])
          .to eq(chef_run.node['postgresql_part']['replication']['replication_slot'])

        expect(chef_run).to create_template("#{chef_run.node['postgresql']['dir']}/recovery.done").with(
          source: 'recovery.conf.erb',
          mode: '0644',
          owner: 'postgres',
          group: 'postgres'
        )
      end
    end

    it 'create pgpass' do
      pgpass = {
        'ip' => partner_ip,
        'port' => chef_run.node['postgresql']['config']['port'],
        'db_name' => 'replication',
        'user' => chef_run.node['postgresql_part']['replication']['user'],
        'passwd' => generate_rep_passwd
      }
      chef_run.node.set['postgres_part']['pgpass'] = pgpass
      chef_run.converge(described_recipe)

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

    it 'restart posgresql service' do
      service_name = 'postgresql'
      chef_run.node.set['postgresql']['server']['service_name'] = service_name
      chef_run.converge(described_recipe)

      service = chef_run.service('postgresql')
      expect(service).to do_nothing
      expect(service.service_name).to eq(service_name)
      expect(chef_run.template("#{chef_run.node['postgresql']['dir']}/recovery.done"))
        .to notify('service[postgresql]').to(:reload).delayed
    end

    it 'create replication slot' do
      query = ["SELECT * FROM pg_create_physical_replication_slot('",
               "#{chef_run.node['postgresql_part']['replication']['replication_slot']}');"].join
      expect(chef_run).to ChefSpec::Matchers::ResourceMatcher.new(
        :postgresql_database,
        :query,
        'postgres'
    ).with(
      connection: postgresql_connection_info,
      sql: query
    )
    end

    it 'include configure_tomcat_session recipe ' do
      expect(chef_run).to include_recipe('postgresql_part::configure_tomcat_session')
    end

    it 'create consul service def' do
      expect(chef_run).to ChefSpec::Matchers::ResourceMatcher.new(
        :cloudconductor_consul_service_def,
        :create,
        'postgresql'
      ).with(
        id: 'postgresql',
        port: 5432,
        tags: ['primary'],
        check: nil
      )
    end
  end
end
