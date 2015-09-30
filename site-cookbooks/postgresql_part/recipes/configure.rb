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
