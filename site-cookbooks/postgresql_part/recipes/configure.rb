#
# Cookbook Name:: postgresql_part
# Recipe:: configure
#
#

require 'timeout'

pgpass = [
  {
    'ip' => '127.0.0.1',
    'port' => node['postgresql']['config']['port'],
    'db_name' => 'replication',
    'user' => node['postgresql_part']['replication']['user'],
    'passwd' => generate_password('db_replication')
  }, {
    'ip' => primary_db_ip,
    'port' => node['postgresql']['config']['port'],
    'db_name' => 'replication',
    'user' => node['postgresql_part']['replication']['user'],
    'passwd' => generate_password('db_replication')
  }, {
    'ip' => standby_db_ip,
    'port' => node['postgresql']['config']['port'],
    'db_name' => 'replication',
    'user' => node['postgresql_part']['replication']['user'],
    'passwd' => generate_password('db_replication')
  }
]

node['cloudconductor']['servers'].each do |_hostname, sv_info|
  next unless sv_info['roles'].include?('ap')

  pgpass << {
    'ip' => sv_info['private_ip'],
    'port' => '9999',
    'db_name' => '*',
    'user' => node['postgresql_part']['application']['user'],
    'passwd' => generate_password('db_application')
  }
end

template "#{node['postgresql_part']['home_dir']}/.pgpass" do
  source 'pgpass.erb'
  mode '0600'
  owner 'postgres'
  group 'postgres'
  variables(
    pgpass: pgpass
  )
end

if primary_db?(node['ipaddress'])
  include_recipe 'postgresql_part::configure_primary'
else
  include_recipe 'postgresql_part::configure_standby'
end
