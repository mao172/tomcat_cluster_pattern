::Chef::Recipe.send(:include, DbHelper)

unless enable_db_names.include?(node[:hostname])
  fail 'DB node is too much, this node to disable'
end

pgpass = {
  'ip' => "#{partner_db['private_ip']}",
  'port' => "#{node['postgresql']['config']['port']}",
  'db_name' => 'replication',
  'user' => "#{node['postgresql_part']['replication']['user']}",
  'passwd' => "#{node['postgresql_part']['replication']['password']}"
}

template "#{node['postgresql_part']['home_dir']}/.pgpass" do
  source 'pgpass.erb'
  mode '0600'
  owner 'postgres'
  group 'postgres'
  variables(
    pgpass: pgpass
  )
end

if primary?
  pg_hba = [
    { type: 'local', db: 'all', user: 'postgres', addr: nil, method: 'ident' },
    { type: 'local', db: 'all', user: 'all', addr: nil, method: 'ident' },
    { type: 'host', db: 'all', user: 'all', addr: '127.0.0.1/32', method: 'md5' },
    { type: 'host', db: 'all', user: 'all', addr: '::1/128', method: 'md5' },
    { type: 'host', db: 'all', user: 'postgres', addr: '0.0.0.0/0', method: 'reject' }
  ]

  pg_hba += db_servers.map do |_name, server|
    {
      type: 'host',
      db: 'replication',
      user: "#{node['postgresql_part']['replication']['user']}",
      addr: "#{server['private_ip']}/32", method: 'md5'
    }
  end
  ap_servers = node['cloudconductor']['servers'].select { |_name, server| server['roles'].include?('ap') }
  pg_hba += ap_servers.map do |_name, server|
    { type: 'host', db: 'all', user: 'all', addr: "#{server['private_ip']}/32", method: 'md5' }
  end
  node.set['postgresql']['pg_hba'] = pg_hba

  template "#{node['postgresql']['dir']}/pg_hba.conf" do
    source 'pg_hba.conf.erb'
    mode '0644'
    owner 'postgres'
    group 'postgres'
    variables(
      pg_hba: node['postgresql']['pg_hba']
    )
    notifies :reload, 'service[postgresql]', :delayed
  end

  postgresql_connection_info = {
    host: '127.0.0.1',
    port: node['postgresql']['config']['port'],
    username: 'postgres',
    password: node['postgresql']['password']['postgres']
  }

  postgresql_database 'postgres' do
    action :query
    connection postgresql_connection_info
    sql "SELECT * FROM pg_create_physical_replication_slot('#{node['postgresql_part']['replication']['replication_slot']}');"
    not_if do
      cmd = ['sudo -u postgres /usr/bin/psql ',
             '-qtA -c "select count(*) from pg_replication_slots ',
             "where slot_name='#{node['postgresql_part']['replication']['replication_slot']}';\""].join
      shell = Mixlib::ShellOut.new(cmd)
      shell.run_command
      shell.stdout.to_i > 0
    end
  end
else
  directory "#{node['postgresql']['dir']}" do
    action :delete
    recursive true
  end

  code = "pg_basebackup -D #{node['postgresql']['dir']} --xlog --verbose -h #{partner_db['private_ip']} -U replication"

  bash 'pg_basebackup' do
    code code
    user 'postgres'
  end

  file "#{node['postgresql']['dir']}/recovery.done" do
    action :delete
  end
end
primary_conninfo = ["host=#{partner_db['private_ip']} ",
                    "port=#{node['postgresql']['config']['port']} ",
                    "user=#{node['postgresql_part']['replication']['user']} ",
                    "password=#{node['postgresql_part']['replication']['password']}"].join
if node['postgresql']['config']['synchronous_commit'].is_a?(TrueClass) ||
   node['postgresql']['config']['synchronous_commit'] == 'on'
  primary_conninfo << " application_name=#{node['postgresql_part']['replication']['application_name']}"
end

node.set['postgresql_part']['recovery']['primary_conninfo'] = primary_conninfo

recovery_conf_name = primary? ? 'recovery.done' : 'recovery.conf'

template "#{node['postgresql']['dir']}/#{recovery_conf_name}" do
  source 'recovery.conf.erb'
  mode '0644'
  owner 'postgres'
  group 'postgres'
  notifies :reload, 'service[postgresql]', :delayed
end

service 'postgresql' do
  service_name node['postgresql']['server']['service_name']
  supports [:restart, :reload, :status]
  action :nothing
end
