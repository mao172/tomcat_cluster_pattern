#
# Cookbook Name:: haproxy_part
# Recipe::configure
#
#

web_servers = node['cloudconductor']['servers'].select { |_, s| s['roles'].include?('web') }

config_pool = Mash.new

conf = node['haproxy']

#
#
def make_hash(attr)
  new_hash = {}
  attr.each do |k, v|
    if v.is_a?(Hash)
      new_hash[k] = make_hash(v)
    else
      new_hash[k] = v
    end
  end
  new_hash
end

##
# config

if conf['enable_stats_socket']
  stats_socket = "#{conf['stats_socket_path']} user #{conf['stats_socket_user']} group #{conf['stats_socket_group']}"

  node.default[:haproxy][:config][:global]['stats socket'] = stats_socket
end

if conf['enable_admin']
  node.default[:haproxy][:config]['listen admin'] = conf['admin']['options']
  bind = "#{conf['admin']['address_bind']}:#{conf['admin']['port']}"
  node.default[:haproxy][:config]['listen admin'][:bind] = bind
  node.default[:haproxy][:config]['listen admin'][:mode] = :http
end

# for HTTP
if conf['enable_default_http']

  config_pool['frontend http'] = {
    maxconn: conf[:frontend_max_connections],
    bind: "#{conf[:incoming_address]}:#{conf[:incoming_port]}",
    default_backend: 'servers-http'
  }
end

# default backend (http)
if conf['enable_default_http'] || node[:haproxy_part][:enable_ssl_proxy]

  servers_http = web_servers.map do |hostname, server|
    "#{hostname} #{server['private_ip']}:#{conf['member_port']} weight 1 maxconn #{conf['member_max_connections']} check"
  end

  options = []

  options << "httpchk #{conf['httpchk']}" if conf['httpchk']

  params = {
    server: servers_http,
    option: options
  }

  config_pool['backend servers-http'] = Chef::Mixin::DeepMerge.merge(make_hash(node[:haproxy_part][:backend_params]), params)

end

# for HTTPS
if conf['enable_ssl']

  config_pool['frontend https'] = {
    'maxconn' => conf['frontend_ssl_max_connections'],
    'bind' => "#{conf['ssl_incoming_address']}:#{conf['ssl_incoming_port']}",
    'default_backend' => 'servers-https'
  }

  servers_https = web_servers.map do |hostname, server|
    "#{hostname} #{server['private_ip']}:#{conf['ssl_member_port']} weight 1 maxconn #{conf['member_max_connections']} check"
  end

  options = ['ssl-hello-chk']

  options << "httpchk #{conf['ssl_httpchk']}" if conf['ssl_httpchk']

  params = {
    mode: :tcp,
    server: servers_https,
    option: options
  }

  config_pool['backend servers-https'] = Chef::Mixin::DeepMerge.merge(make_hash(node[:haproxy_part][:backend_params]), params)

else
  # SSL Proxy
  if node[:haproxy_part][:enable_ssl_proxy]
    directory "#{node[:haproxy_part][:ssl_pem_dir]}" do
      owner 'root'
      group 'root'
      mode  '0755'
    end

    haproxy_part_pem_file "#{node[:haproxy_part][:ssl_pem_file]}"

    bind = "#{conf['ssl_incoming_address']}:#{conf['ssl_incoming_port']} ssl crt #{node[:haproxy_part][:ssl_pem_file]}"

    config_pool['frontend ssl-proxy'] = {
      'maxconn' => conf['frontend_ssl_max_connections'],
      'bind' => bind,
      'mode' => :http,
      'default_backend' => 'servers-http'
    }
  end
end

# Create HAProxy Configurations
haproxy 'myhaproxy' do
  config config_pool
end
