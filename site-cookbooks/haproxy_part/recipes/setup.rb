#
# Cookbook Name:: haproxy_part
# Recipe:: setup
#
#

include_recipe 'haproxy'

##
if node[:haproxy_part][:rsyslog][:config]
  node.default[:haproxy_part][:rsyslog][:setup] = true unless ::File.exist?("#{node['rsyslog']['config_prefix']}/rsyslog.d")

  include_recipe 'rsyslog' if node[:haproxy_part][:rsyslog][:setup]

  directory "#{node[:haproxy_part][:log_dir]}" do
    owner 'root'
    group 'root'
    mode '0700'
  end

  template "#{node['rsyslog']['config_prefix']}/rsyslog.d/20-haproxy.conf" do
    source 'rsyslog-haproxy.conf.erb'
    owner 'root'
    group 'root'
    mode  '0644'
    notifies :restart, "service[#{node['rsyslog']['service_name']}]"
  end
end

unless node[:haproxy_part][:rsyslog][:setup]
  service node['rsyslog']['service_name'] do
    supports restart: true, reload: true, status: true
    action   [:enable, :start]
  end
end
