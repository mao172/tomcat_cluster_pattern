db_servers = node['cloudconductor']['servers'].select { |_name, server| server['roles'].include?('db') }

db_servers.each_with_index do | (_name, server), index |
  node.set['pgpool_part']['pgconf']["backend_hostname#{index}"] = server['private_ip']
  node.set['pgpool_part']['pgconf']["backend_port#{index}"] = node['pgpool_part']['postgresql']['port']
  node.set['pgpool_part']['pgconf']["backend_data_directory#{index}"] = node['pgpool_part']['postgresql']['dir']
  node.set['pgpool_part']['pgconf']["backend_flag#{index}"] = 'ALLOW_TO_FAILOVER'
end

template "#{node['pgpool_part']['config']['dir']}/pgpool.conf" do
  owner 'root'
  group 'root'
  mode '0764'
  notifies :restart, 'service[pgpool]', :delayed
end

service 'pgpool' do
  service_name node['pgpool_part']['service']
  action :nothing
end
