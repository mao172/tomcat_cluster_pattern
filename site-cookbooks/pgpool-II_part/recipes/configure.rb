require 'digest/md5'
require 'timeout'

timeout = node[:pgpool_part][:wait_timeout]
interval = node[:pgpool_part][:wait_interval]

Timeout.timeout(timeout) do
  while CloudConductor::ConsulClient::Catalog.service('postgresql', tag: 'primary').empty?
    puts 'waiting for primary ...'
    sleep interval
  end
end

def servers(role)
  node['cloudconductor']['servers'].select { |_name, server| server['roles'].include?(role) }
end

node.set['pgpool_part']['pgconf']['sr_check_password'] = generate_password('db_replication_check')

db_servers = servers('db')

db_servers.each_with_index do |(_name, server), index|
  node.set['pgpool_part']['pgconf']["backend_hostname#{index}"] = server['private_ip']
  node.set['pgpool_part']['pgconf']["backend_port#{index}"] = node['pgpool_part']['postgresql']['port'].to_i
  node.set['pgpool_part']['pgconf']["backend_data_directory#{index}"] = node['pgpool_part']['postgresql']['dir']
  node.set['pgpool_part']['pgconf']["backend_flag#{index}"] = node['pgpool_part']['pgconf']['backend_flag0']
  node.set['pgpool_part']['pgconf']["backend_weight#{index}"] = node['pgpool_part']['pgconf']['backend_weight0']
end

other_ap_servers = servers('ap').delete_if { |_key, val| val['private_ip'] == node[:ipaddress] }

if other_ap_servers.length < 1
  node.set['pgpool_part']['pgconf']['use_watchdog'] = false
else
  other_ap_servers.each_with_index do |(_name, server), index|
    node.set['pgpool_part']['pgconf']["other_pgpool_hostname#{index}"] = server['private_ip']
    node.set['pgpool_part']['pgconf']["other_pgpool_port#{index}"] = node['pgpool_part']['pgconf']['port']
    node.set['pgpool_part']['pgconf']["other_wd_port#{index}"] = node['pgpool_part']['pgconf']['wd_port']
    node.set['pgpool_part']['pgconf']["heartbeat_destination#{index}"] = server['private_ip']
    node.set['pgpool_part']['pgconf']["heartbeat_destination_port#{index}"] = node['pgpool_part']['pgconf']['wd_heartbeat_port']
  end
end

ruby_block 'wait-unless-completed-database' do
  block do
    require 'timeout'

    def servers(role)
      node['cloudconductor']['servers'].select { |_name, server| server['roles'].include?(role) }
    end

    timeout = node[:pgpool_part][:wait_timeout]
    interval = node[:pgpool_part][:wait_interval]
    port = node[:pgpool_part][:postgresql][:port]

    Timeout.timeout(timeout) do
      servers('db').each do |_name, server|
        until system("hping3 -S #{server[:private_ip]} -p #{port} -c 5 ")
          puts "... waiting for completed database (#{server[:private_ip]}:#{port}) ..."
          sleep interval
        end
      end
    end
  end
  notifies :restart, 'service[pgpool]', :immediately
  action :nothing
end

pgpool_II_part_config_file 'create-conf-file' do
  owner 'root'
  group 'root'
  mode  '0764'
  notifies :run, 'ruby_block[wait-unless-completed-database]', :delayed
end

bash 'create md5 auth setting' do
  code ["pg_md5 --md5auth --username=#{node['pgpool_part']['postgresql']['application']['user']} ",
        "#{generate_password('db_application')}"].join
end

bash 'create md5 auth setting for tomcat user' do
  code "pg_md5 --md5auth --username=#{node['pgpool_part']['postgresql']['tomcat']['user']} #{generate_password('tomcat')}"
end

service 'pgpool' do
  service_name node['pgpool_part']['service']
  action :nothing
end
