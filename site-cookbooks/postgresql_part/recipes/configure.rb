::Chef::Resource.send(:include, ConsulHelper)

# setting pg_hba.conf
pg_hba = [
  { type: 'local', db: 'all', user: 'postgres', addr: nil, method: 'ident' },
  { type: 'local', db: 'all', user: 'all', addr: nil, method: 'ident' },
  { type: 'host', db: 'all', user: 'all', addr: '127.0.0.1/32', method: 'md5' },
  { type: 'host', db: 'all', user: 'all', addr: '::1/128', method: 'md5' },
  { type: 'host', db: 'all', user: 'postgres', addr: '0.0.0.0/0', method: 'reject' }
]

%w(db ap).each do |role|
  servers = node['cloudconductor']['servers'].select { |_name, server| server['roles'].include?(role) }
  pg_hba += servers.map do |_name, server|
    { type: 'host', db: 'all', user: 'all', addr: "#{server['private_ip']}/32", method: 'md5' }
  end
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
end

service 'postgresql' do
  service_name node['postgresql']['server']['service_name']
  supports [:restart, :reload, :status]
  action :nothing
end
