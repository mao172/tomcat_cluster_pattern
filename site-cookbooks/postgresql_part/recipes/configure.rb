#
# Cookbook Name:: postgresql_part
# Recipe:: configure
#
#

require 'timeout'

if is_primary_db?(node[:ipaddress])
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
