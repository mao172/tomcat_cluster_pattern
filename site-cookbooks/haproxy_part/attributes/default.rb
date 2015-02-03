#
# Cookbook Name:: haproxy_part
# Attribute:: default
#
#

# for setup to Haproxy
default['haproxy']['install_method'] = 'source'
default['haproxy']['package']['version'] = nil

default['haproxy']['source']['version'] = '1.5.11'
default['haproxy']['source']['url'] = 'http://www.haproxy.org/download/1.5/src/haproxy-1.5.11.tar.gz'
default['haproxy']['source']['checksum'] = '8b5aa462988405f09c8a6169294b202d7f524a5450a02dd92e7c216680f793bf'
default['haproxy']['source']['use_pcre'] = true
default['haproxy']['source']['use_openssl'] = true
default['haproxy']['source']['use_zlib'] = true

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

# for sticky session
default[:haproxy_part][:enable_sticky_session] = true
default[:haproxy_part][:sticky_session_method] = :cookie
default[:haproxy_part][:cookie] = 'SERVERID insert indirect nocache'
default[:haproxy_part][:appsession] = 'JSESSIONID len 32 timeout 3h request-learn'
# backend params
default[:haproxy_part][:backend_params] = {}

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
