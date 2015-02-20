#
# Cookbook Name::postgresql_part
# Recipe:: configure_standby
#
#

# puts "primary ip=#{primary_db_ip}"
# puts "standby ip=#{standby_db_ip}"
# puts "host ip= #{node[:ipaddress]}"

pgpass = {
  'ip' => "#{primary_db_ip}",
  'port' => "#{node['postgresql']['config']['port']}",
  'db_name' => 'replication',
  'user' => "#{node['postgresql_part']['replication']['user']}",
  'passwd' => generate_password('db_replication')
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

ruby_block 'stop_postgresql' do
  block {}
  notifies :stop, 'service[postgresql]', :immediately
end

directory "#{node['postgresql']['dir']}" do
  action :delete
  recursive true
end

code = "sudo -u postgres /usr/bin/pg_basebackup -D #{node['postgresql']['dir']} --xlog --verbose -h #{primary_db_ip} -U replication"

bash 'pg_basebackup' do
  code code
  notifies :start, 'service[postgresql]', :immediately
end

file "#{node['postgresql']['dir']}/recovery.done" do
  action :delete
end

primary_conninfo = ["host=#{primary_db_ip} ",
                    "port=#{node['postgresql']['config']['port']} ",
                    "user=#{node['postgresql_part']['replication']['user']} ",
                    "password=#{node['postgresql_part']['replication']['password']}"].join

if node['postgresql']['config']['synchronous_commit'].is_a?(TrueClass) ||
   node['postgresql']['config']['synchronous_commit'] == 'on'
  primary_conninfo << " application_name=#{node['postgresql_part']['replication']['application_name']}"
end

node.set['postgresql_part']['recovery']['primary_conninfo'] = primary_conninfo

template "#{node['postgresql']['dir']}/recovery.conf" do
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
