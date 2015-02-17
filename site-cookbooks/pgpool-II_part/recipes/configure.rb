require 'digest/md5'

def servers(role)
  node['cloudconductor']['servers'].select { |_name, server| server['roles'].include?(role) }
end

db_servers = servers('db')

db_servers.each_with_index do | (_name, server), index |
  node.set['pgpool_part']['pgconf']["backend_hostname#{index}"] = server['private_ip']
  node.set['pgpool_part']['pgconf']["backend_port#{index}"] = node['pgpool_part']['postgresql']['port']
  node.set['pgpool_part']['pgconf']["backend_data_directory#{index}"] = node['pgpool_part']['postgresql']['dir']
  node.set['pgpool_part']['pgconf']["backend_flag#{index}"] = node['pgpool_part']['pgconf']['backend_flag0']
  node.set['pgpool_part']['pgconf']["backend_weight#{index}"] = node['pgpool_part']['pgconf']['backend_weight0']
end

ap_servers = servers('ap')
other_ap_servers = ap_servers.delete_if { |_key, val| val['private_ip'] == node[:ipaddress] }

other_ap_servers.each_with_index do | (_name, server), index |
  node.set['pgpool_part']['pgconf']["other_pgpool_hostname#{index}"] = server['private_ip']
  node.set['pgpool_part']['pgconf']["other_pgpool_port#{index}"] = node['pgpool_part']['pgconf']['port']
  node.set['pgpool_part']['pgconf']["other_wd_port#{index}"] = node['pgpool_part']['pgconf']['wd_port']
  node.set['pgpool_part']['pgconf']["heartbeat_destination#{index}"] = server['private_ip']
  node.set['pgpool_part']['pgconf']["heartbeat_destination_port#{index}"] = node['pgpool_part']['pgconf']['wd_heartbeat_port']
end

file "#{node['pgpool_part']['config']['dir']}/pcp.conf" do
  owner 'root'
  group 'root'
  mode '0764'
  content "#{node['pgpool_part']['user']}:#{Digest::MD5.hexdigest(generate_password('pcp'))}"
  notifies :restart, 'service[pgpool]', :delayed
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
