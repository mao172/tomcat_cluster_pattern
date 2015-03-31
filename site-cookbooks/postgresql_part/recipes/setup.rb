include_recipe 'postgresql::server'
include_recipe 'postgresql::ruby'

# initdb
bash 'run_initdb' do
  code "service postgresql-#{node['postgresql']['version']} initdb"
  only_if { Dir.glob("#{node['postgresql']['dir']}/*").empty? }
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

  postgresql_connection_info = {
    host: '127.0.0.1',
    port: node['postgresql']['config']['port'],
    username: 'postgres',
    password: node['postgresql']['password']['postgres']
  }

  postgresql_database 'template1' do
    action :query
    connection postgresql_connection_info
    sql lazy { ::File.read("#{Chef::Config[:file_cache_path]}/pgpool-II-3.4.0/src/sql/pgpool-regclass/pgpool-regclass.sql") }
  end

  event_handlers_dir = node['postgresql_part']['event_handlers_dir']

  # create directory for Consul event-handler
  directory event_handlers_dir do
    owner 'root'
    group 'root'
    mode 0755
    recursive true
    action :create
  end

  cookbook_file 'failover_action.rb' do
    path File.join(event_handlers_dir, 'failover_action.rb')
    mode 0755
    owner 'root'
    user 'root'
    action :create
  end

  template File.join(event_handlers_dir, 'failover_event_handler') do
    source 'failover_event_handler'
    mode 0755
    owner 'root'
    user 'root'
    variables(
      action_script: 'failover_action.rb'
    )
  end

  consul_event_watch_def 'failover' do
    handler "#{File.join(event_handlers_dir, 'failover_event_handler')} failover"
    action :create
  end

  cookbook_file 'check-state-event-handler' do
    path File.join(event_handlers_dir, 'check-state-event-handler')
    mode 0755
    owner 'root'
    user 'root'
  end

  consul_config_dir = node['cloudconductor']['consul']['config_dir']

  cookbook_file 'check-postgresql.json' do
    path File.join(consul_config_dir, 'check-postgresql.json')
    mode 0644
    owner 'root'
    user 'root'
  end
end
