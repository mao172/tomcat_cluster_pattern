include_recipe 'postgresql::server'
include_recipe 'postgresql::ruby'

# initdb
bash 'run_initdb' do
  code "service postgresql-#{node['postgresql']['version']} initdb"
  only_if { Dir.glob("#{node['postgresql']['dir']}/*").empty? }
end

postgresql_connection_info = {
  host: '127.0.0.1',
  port: node['postgresql']['config']['port'],
  username: 'postgres',
  password: node['postgresql']['password']['postgres']
}

postgresql_database_user node['postgresql_part']['replication']['user'] do
  connection postgresql_connection_info
  password node['postgresql_part']['replication']['password']
  action :create
  replication true
end

postgresql_database_user node['postgresql_part']['application']['user'] do
  connection postgresql_connection_info
  password node['postgresql_part']['application']['password']
  action :create
end

postgresql_database node['postgresql_part']['application']['database'] do
  connection postgresql_connection_info
  owner node['postgresql_part']['application']['user']
  action :create
end

if node['postgresql_part']['pgpool-II']['use']
  remote_file "#{Chef::Config[:file_cache_path]}/pgpool-II-3.4.0.tar.gz" do
    source node['postgresql_part']['pgpool-II']['source_archive_url']
  end

  bash 'extract_archive_file' do
    code "tar xvf #{Chef::Config[:file_cache_path]}/pgpool-II-3.4.0.tar.gz -C #{Chef::Config[:file_cache_path]}/"
  end

  bash 'install_pgpool-II' do
    code <<-EOS
      export PATH=/usr/pgsql-9.4/bin/:$PATH
      cd #{Chef::Config[:file_cache_path]}/pgpool-II-3.4.0/src/sql/pgpool-regclass/
      make
      make install
  EOS
  end

  postgresql_database 'template1' do
    action :query
    connection postgresql_connection_info
    sql lazy { ::File.read("#{Chef::Config[:file_cache_path]}/pgpool-II-3.4.0/src/sql/pgpool-regclass/pgpool-regclass.sql") }
  end
end
