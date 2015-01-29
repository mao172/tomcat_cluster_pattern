#
# Cookbook Name:: haproxy_part
# Attribute:: default
#
#

# for setup to Haproxy
default['haproxy']['install_method'] = 'package'
default['haproxy']['member_port'] = 80

# for frontend ssl_proxy
default[:haproxy_part][:enable_ssl_proxy] = true
default[:haproxy_part][:ssl_pem_dir] = "#{node['haproxy']['conf_dir']}"
default[:haproxy_part][:ssl_pem_file] = "#{node[:haproxy_part][:ssl_pem_dir]}/server.pem"

# for pem file received
default[:haproxy_part][:pem_file][:protocol] = 'consul'
default[:haproxy_part][:pem_file][:uri] = '/shared/ssl/server.pem'
default[:haproxy_part][:pem_file][:consul][:key] = 'ssl_pem'
default[:haproxy_part][:pem_file][:consul][:value_type] = 'text'
default[:haproxy_part][:pem_file][:property_nm] = nil

# backend params
default[:haproxy_part][:backend_params] = { appsession: 'JSESSIONID len 32 timeout 3s request-learn' }

# install rsyslog package
default[:haproxy_part][:rsyslog][:setup] = false # true

# configure haproxy log on rsyslog
default[:haproxy_part][:rsyslog][:config] = true

default[:haproxy_part][:log_dir] = "#{node[:rsyslog][:default_log_dir]}/haproxy"
# default[:haproxy_part][:log_protocol] = 'udp'
# default[:haproxy_part][:log_port] = 514
default[:haproxy_part][:log_template] = 'Haproxy,"%msg%\n"'
default[:haproxy_part][:log_rules]['local0.=info'] = "-#{node[:haproxy_part][:log_dir]}/haproxy.log;Haproxy"
default[:haproxy_part][:log_rules]['local0.notice'] = "-#{node[:haproxy_part][:log_dir]}/admin.log;Haproxy"
default[:haproxy_part][:log_rules]['local0.*'] = '~'
