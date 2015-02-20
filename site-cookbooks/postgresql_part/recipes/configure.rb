#
# Cookbook Name:: postgresql_part
# Recipe:: configure
#
#



if is_primary_db?(node[:ipaddress])
  include_recipe 'postgresql_part::configure_primary'

else



  include_recipe 'postgresql_part::configure_standby'
end
