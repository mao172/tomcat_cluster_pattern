#
# Cookbook Name:: postgresql_part
# Recipe:: configure
#
#

require 'timeout'

pgpass = [
  {
    'ip' => '172.0.0.1',
    'port' => "#{node['postgresql']['config']['port']}",
    'db_name' => 'replication',
    'user' => "#{node['postgresql_part']['replication']['user']}",
    'passwd' => generate_password('db_replication')
  }, {
    'ip' => "#{primary_db_ip}",
    'port' => "#{node['postgresql']['config']['port']}",
    'db_name' => 'replication',
    'user' => "#{node['postgresql_part']['replication']['user']}",
    'passwd' => generate_password('db_replication')
  }, {
    'ip' => "#{standby_db_ip}",
    'port' => "#{node['postgresql']['config']['port']}",
    'db_name' => 'replication',
    'user' => "#{node['postgresql_part']['replication']['user']}",
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

if primary_db?(node[:ipaddress])
  include_recipe 'postgresql_part::configure_primary'

else

  # wait_until_completed_primary
  timeout = node[:postgresql_part][:wait_timeout]
  interval = node[:postgresql_part][:wait_interval]

  Timeout.timeout(timeout) do
    while CloudConductor::ConsulClient::Catalog.service('postgresql', tag: 'primary').empty?
      puts 'waiting for primary ...'
      sleep interval
    end
  end

  include_recipe 'postgresql_part::configure_standby'
end
