require_relative '../spec_helper'
require 'chefspec'

describe 'postgresql_part::configure' do
  let(:chef_run) { ChefSpec::SoloRunner.new }

  myself_hostname = 'myself'
  myself_ip = '172.0.0.10'
  partner_hostname = 'partner'
  partner_ip = '172.0.0.11'
  ap_ip = '172.0.0.1'
  ap2_ip = '172.0.0.2'

  before do
    chef_run.node.set['postgresql']['version'] = '9.4'
    chef_run.node.set['postgresql']['config']['port'] = '5432'
    chef_run.node.set['postgresql']['assign_postgres_password'] = true
    chef_run.node.set['postgresql']['password']['postgres'] = 'dba_passwd'
    chef_run.node.set['postgresql_part']['replication']['user'] = 'replication_user'
    chef_run.node.set['postgresql_part']['replication']['passwd'] = 'replication_pass'
    chef_run.node.set['postgresql_part']['replication']['replication_slot'] = 'chef_spec_slot'
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
    chef_run.converge(described_recipe)
  end

  describe 'identify a own node type' do
    describe 'primary db is registerd in catalog of consul' do
      def helper_response(hostname, ipaddress)
        [{
          'Node' => "#{hostname}",
          'Address' => "#{ipaddress}",
          'ServiceID' => 'db',
          'ServiceName' => 'db',
          'ServiceTags' => ['primary'],
          'ServicePort' => 5432
        }]
      end

      describe 'primary db is this node' do
        it 'do configure for primary db' do
          allow_any_instance_of(ConsulHelper::Helper).to receive(:find_node_possession_tag)
            .and_return(helper_response(myself_hostname, myself_ip))
          chef_run.converge(described_recipe)

          expect(chef_run).to create_template("#{chef_run.node['postgresql']['dir']}/recovery.done")
        end
      end
      describe 'primary db is not this node' do
        it 'do configure for standby db' do
          allow_any_instance_of(ConsulHelper::Helper).to receive(:find_node_possession_tag)
            .and_return(helper_response(partner_hostname, partner_ip))
          chef_run.converge(described_recipe)

          expect(chef_run).to create_template("#{chef_run.node['postgresql']['dir']}/recovery.conf")
        end
      end
    end
    describe 'primary db is not registerd in catalog of consul' do
      before do
        allow_any_instance_of(ConsulHelper::Helper).to receive(:find_node_possession_tag).and_return([])
      end
      describe 'first entry of servers is this node' do
        it 'do configure for primary db' do
          chef_run.node.set['cloudconductor']['servers'] = {
            myself_hostname => { roles: 'db', private_ip: myself_ip },
            partner_hostname => { roles: 'db', private_ip: partner_ip },
            ap_server: { roles: 'ap', private_ip: ap_ip }
          }
          chef_run.converge(described_recipe)
          expect(chef_run).to create_template("#{chef_run.node['postgresql']['dir']}/recovery.done")
        end
      end
      describe 'first entry of servers is not this node' do
        it 'do configure for standby db' do
          chef_run.node.set['cloudconductor']['servers'] = {
            partner_hostname => { roles: 'db', private_ip: partner_ip },
            myself_hostname => { roles: 'db', private_ip: myself_ip },
            ap_server: { roles: 'ap', private_ip: ap_ip }
          }
          chef_run.converge(described_recipe)
          expect(chef_run).to create_template("#{chef_run.node['postgresql']['dir']}/recovery.conf")
        end
      end
    end
  end

  describe 'itself is Master db node' do
    before do
      allow_any_instance_of(ConsulHelper::Helper).to receive(:find_node_possession_tag).and_return([])
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

    describe 'synchronous replication' do
      it 'create recovery.done' do
        chef_run.node.set['postgresql']['config']['synchronous_commit'] = 'on'
        chef_run.converge(described_recipe)

        primary_conninfo =  ["host=#{partner_ip} port=#{chef_run.node['postgresql']['config']['port']} ",
                             "user=#{chef_run.node['postgresql_part']['replication']['user']} ",
                             "password=#{chef_run.node['postgresql_part']['replication']['password']} ",
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
                             "password=#{chef_run.node['postgresql_part']['replication']['password']}"].join

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
        'passwd' => chef_run.node['postgresql_part']['replication']['password']
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
      postgresql_connection_info = {
        host: '127.0.0.1',
        port: chef_run.node['postgresql']['config']['port'],
        username: 'postgres',
        password: chef_run.node.set['postgresql']['password']['postgres']
      }

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
  end

  describe 'itself is standby db node' do
    before do
      allow_any_instance_of(ConsulHelper::Helper).to receive(:find_node_possession_tag).and_return([])
      chef_run.node.automatic_attrs['hostname'] = myself_hostname
      chef_run.node.automatic_attrs['ipaddress'] = myself_ip
      chef_run.node.set['cloudconductor']['servers'] = {
        partner_hostname => {
          roles: 'db',
          private_ip: partner_ip
        },
        myself_hostname => {
          roles: 'db',
          private_ip: myself_ip
        },
        ap_server: {
          roles: 'ap',
          private_ip: ap_ip
        }
      }
      chef_run.converge(described_recipe)
    end

    it 'create pgpass' do
      pgpass = {
        'ip' => partner_ip,
        'port' => chef_run.node['postgresql']['config']['port'],
        'db_name' => 'replication',
        'user' => chef_run.node['postgresql_part']['replication']['user'],
        'passwd' => chef_run.node['postgresql_part']['replication']['password']
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
      expect(chef_run).to run_bash('pg_basebackup').with(
        code: "sudo -u postgres /usr/bin/pg_basebackup -D #{chef_run.node['postgresql']['dir']} --xlog --verbose -h #{partner_ip} -U replication",
      )
      expect(chef_run.bash('pg_basebackup'))
        .to notify('service[postgresql]').to(:start).immediately
    end

    it 'delete recovery.done' do
      expect(chef_run).to delete_file("#{chef_run.node['postgresql']['dir']}/recovery.done")
    end

    describe 'synchronous replication' do
      it 'create recovery.conf' do
        chef_run.node.set['postgresql']['config']['synchronous_commit'] = 'on'
        chef_run.node.set['postgresql_part']['replication']['application_name'] = 'application'
        chef_run.converge(described_recipe)

        primary_conninfo = ["host=#{partner_ip} port=#{chef_run.node['postgresql']['config']['port']} ",
                            "user=#{chef_run.node['postgresql_part']['replication']['user']} ",
                            "password=#{chef_run.node['postgresql_part']['replication']['password']} ",
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

        primary_conninfo =  ["host=#{partner_ip} port=#{chef_run.node['postgresql']['config']['port']} ",
                             "user=#{chef_run.node['postgresql_part']['replication']['user']} ",
                             "password=#{chef_run.node['postgresql_part']['replication']['password']}"].join

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
        .to notify('service[postgresql]').to(:reload).delayed
    end
  end
end
