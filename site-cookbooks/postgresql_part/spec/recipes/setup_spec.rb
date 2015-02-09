require_relative '../spec_helper'
require 'chefspec'

describe 'postgresql_part::default' do
  let(:chef_run) { ChefSpec::SoloRunner.new }

  pgsql_version = '9.4'
  port = '5432'
  dba_passwd = 'password'
  replication_user = 'rep_user'
  replication_pass = 'rep_pass'
  app_user = 'app_user'
  app_pass = 'app_pass'
  app_db = 'app_db'

  pgpool_source = 'http://www.pgpool.net/download.php?f=pgpool-II-3.4.0.tar.gz'

  postgresql_connection_info = {
    host: '127.0.0.1',
    port: port,
    username: 'postgres',
    password: dba_passwd
  }

  before do
    stub_command("ls /var/lib/pgsql/#{pgsql_version}/data/recovery.conf")

    chef_run.node.set['postgresql']['version'] = pgsql_version
    chef_run.node.set['postgresql']['config']['port'] = port
    chef_run.node.set['postgresql']['assign_postgres_password'] = true
    chef_run.node.set['postgresql']['password']['postgres'] = dba_passwd
    chef_run.node.set['postgresql_part']['replication']['user'] = replication_user
    chef_run.node.set['postgresql_part']['replication']['password'] = replication_pass
    chef_run.node.set['postgresql_part']['application']['user'] = app_user
    chef_run.node.set['postgresql_part']['application']['password'] = app_pass
    chef_run.node.set['postgresql_part']['application']['database'] = app_db
    chef_run.node.set['postgresql_part']['pgpool-II']['use'] = true
    chef_run.node.set['postgresql_part']['pgpool-II']['source_archive_url'] = pgpool_source
    chef_run.converge(described_recipe)
  end

  it 'include server recipe of postgresql cookbook' do
    expect(chef_run).to include_recipe 'postgresql::server'
  end

  it 'install postgresql-server package' do
    expect(chef_run).to install_package "postgresql#{pgsql_version.split('.').join}-server"
  end

  it 'install postgresql-devel package' do
    expect(chef_run).to install_package "postgresql#{pgsql_version.split('.').join}-devel"
  end

  it 'include ruby recipe of postgresql cookbook' do
    expect(chef_run).to include_recipe 'postgresql::ruby'
  end

  it 'create postgresql.conf' do
    expect(chef_run).to create_template("#{chef_run.node['postgresql']['dir']}/postgresql.conf")
  end

  it 'execute initdb' do
    allow(Dir).to receive(:glob).and_call_original
    allow(Dir).to receive(:glob).with("#{chef_run.node['postgresql']['dir']}/*").and_return([])
    chef_run.converge(described_recipe)
    expect(chef_run).to run_bash('run_initdb').with(
      code: "service postgresql-#{pgsql_version} initdb"
    )
  end

  it 'assign postgres password' do
    expect(chef_run).to run_bash('assign-postgres-password').with(
      code: "  echo \"ALTER ROLE postgres ENCRYPTED PASSWORD '#{dba_passwd}';\" | psql -p #{port}\n"
    )
  end

  describe 'not assign postgres password' do
    it 'not assign postgres password' do
      chef_run.node.set['postgresql']['assign_postgres_password'] = false
      chef_run.converge(described_recipe)
      expect(chef_run).to_not run_bash('assign-postgres-password')
    end
  end

  it 'install gcc' do
    expect(chef_run).to install_package('gcc')
  end

  it 'install make' do
    expect(chef_run).to install_package('make')
  end

  it 'download pgpool-II archive file' do
    expect(chef_run).to create_remote_file("#{Chef::Config[:file_cache_path]}/pgpool-II-3.4.0.tar.gz").with(
      source: pgpool_source
    )
  end

  it 'extract archive file' do
    expect(chef_run).to run_bash('extract_archive_file').with(
     code: "tar xvf #{Chef::Config[:file_cache_path]}/pgpool-II-3.4.0.tar.gz -C #{Chef::Config[:file_cache_path]}/"
    )
  end

  it 'install pgpool-II' do
    expect(chef_run).to run_bash('install_pgpool-II').with(
      code: <<-EOS
      export PATH=/usr/pgsql-9.4/bin/:$PATH
      cd #{Chef::Config[:file_cache_path]}/pgpool-II-3.4.0/src/sql/pgpool-regclass/
      make
      make install
EOS
    )
  end

  it 'install pgpool-regclass' do
    query = 'query string'
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read)
      .with("#{Chef::Config[:file_cache_path]}/pgpool-II-3.4.0/src/sql/pgpool-regclass/pgpool-regclass.sql").and_return(query)

    expect(chef_run).to ChefSpec::Matchers::ResourceMatcher.new(
      :postgresql_database,
      :query,
      'template1'
    ).with(
      connection: postgresql_connection_info,
      sql: query
    )
  end

  describe 'not use pgpool-II' do
    before do
      chef_run.node.set['postgresql_part']['pgpool-II']['use'] = false
      chef_run.converge(described_recipe)
    end

    it 'not download pgpool-II archive file' do
      expect(chef_run).to_not create_remote_file("#{Chef::Config[:file_cache_path]}/pgpool-II-3.4.0.tar.gz")
    end

    it 'not decompression archive file' do
      expect(chef_run).to_not run_bash('extract_archive_file')
    end

    it 'not add path, make and make install' do
      expect(chef_run).to_not ChefSpec::Matchers::ResourceMatcher.new(
        :postgresql_database,
        :query,
        'template1'
      )
    end
  end
end
