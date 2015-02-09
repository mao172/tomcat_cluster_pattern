require_relative '../spec_helper'
require 'chefspec'

describe 'postgresql_part::deploy' do
  let(:chef_run) { ChefSpec::SoloRunner.new }

  myself_hostname = 'myself'
  myself_ip = '172.0.0.10'
  partner_hostname = 'partner'
  partner_ip = '172.0.0.11'
  app_name = 'app'

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

  before do
    chef_run.node.set['cloudconductor']['servers'] = {
      myself_hostname => { roles: 'db', private_ip: myself_ip },
      partner_hostname => { roles: 'db', private_ip: partner_ip }
    }

    chef_run.node.automatic_attrs['hostname'] = myself_hostname
    chef_run.node.automatic_attrs['ipaddress'] = myself_ip
  end

  describe 'primary db is this node' do
    before do
      chef_run.node.set['cloudconductor']['applications'] = {
        app_name => {
          type: 'dynamic'
        }
      }
      chef_run.converge(described_recipe)

      allow_any_instance_of(ConsulHelper::Helper).to receive(:find_node_possession_tag)
        .and_return(helper_response(myself_hostname, myself_ip))
      chef_run.converge(described_recipe)
    end

    describe 'dynamic type application is included "cloudconductor applications"' do
      describe 'migration type is sql' do
        before do
          chef_run.node.set['cloudconductor']['applications'][app_name]['parameters'] = {
            migration: {
              type: 'sql'
            }
          }
          chef_run.converge(described_recipe)
        end

        describe 'migration url is included applications parameter' do
          it 'download migration file' do
            url = 'http://cloudconductor.org/migration.sql'
            chef_run.node.set['cloudconductor']['applications'][app_name]['parameters']['migration']['url'] = url
            chef_run.converge(described_recipe)
            expect(chef_run).to create_remote_file("#{Chef::Config[:file_cache_path]}/#{app_name}.sql").with(
              source: url
            )
          end
        end

        describe 'migration type is not included' do
          it 'create migration file' do
            query = 'migration sql strings'
            chef_run.node.set['cloudconductor']['applications'][app_name]['parameters']['migration']['query'] = query
            chef_run.converge(described_recipe)
            expect(chef_run).to create_file("#{Chef::Config[:file_cache_path]}/app.sql").with(
              content: query
            )
          end
        end

        describe 'tables is not exist in postgresql db' do
          it 'do migration' do
            db_host = '127.0.0.1'
            db_port = '5432'
            db_user = 'pgsql'
            db_pass = 'passwd'

            postgresql_connection_info = {
              host: db_host,
              port: db_port,
              username: db_user,
              password: db_pass
            }

            chef_run.node.set['postgresql']['config']['port'] = db_port
            chef_run.node.set['postgresql_part']['application']['user'] = db_user

            db_name = 'app_db'
            chef_run.node.set['postgresql_part']['application']['database'] = db_name

            allow_any_instance_of(Mixlib::ShellOut).to receive(:runcommand)
            allow_any_instance_of(Mixlib::ShellOut).to receive(:stdout).and_return('0')
            allow_any_instance_of(Chef::Recipe).to receive(:generate_password).and_return(db_pass)

            chef_run.converge(described_recipe)

            expect(chef_run).to ChefSpec::Matchers::ResourceMatcher.new(
              :postgresql_database,
              :query,
              db_name
            ).with(
              connection: postgresql_connection_info
            )
          end
        end

        describe 'tables is exist in postgresql db' do
          it 'do not migration' do
            db_name = 'app_db'
            chef_run.node.set['postgresql_part']['application']['database'] = db_name

            allow_any_instance_of(Mixlib::ShellOut).to receive(:runcommand)
            allow_any_instance_of(Mixlib::ShellOut).to receive(:stdout).and_return('1')
            chef_run.converge(described_recipe)

            expect(chef_run).to_not ChefSpec::Matchers::ResourceMatcher.new(
              :postgresql_database,
              :query,
              db_name
            )
          end
        end
      end
    end
  end
  describe 'primary db is not this node' do
    before do
      chef_run.node.set['cloudconductor']['applications'] = {
        app_name => {
          type: 'dynamic',
          parameters: {
            migration: {
              type: 'sql'
            }
          }
        }
      }

      chef_run.converge(described_recipe)

      allow_any_instance_of(ConsulHelper::Helper).to receive(:find_node_possession_tag)
        .and_return(helper_response(partner_hostname, partner_ip))
      chef_run.converge(described_recipe)
    end
    describe 'tables is not exist in postgresql db' do
      it 'do not migration' do
        db_name = 'app_db'
        chef_run.node.set['postgresql_part']['application']['database'] = db_name

        allow_any_instance_of(Mixlib::ShellOut).to receive(:runcommand)
        allow_any_instance_of(Mixlib::ShellOut).to receive(:stdout).and_return('0')

        chef_run.converge(described_recipe)

        expect(chef_run).to_not ChefSpec::Matchers::ResourceMatcher.new(
          :postgresql_database,
          :query,
          db_name
        )
      end
    end
  end
end
