#
# Cookbook Name:: haproxy_part
# Recipe:: configure
#
#

extend Chef::Mixin::DeepMerge

web_servers = node['cloudconductor']['servers'].select { |_, s| s['roles'].include?('web') }

config_pool = Mash.new

conf = node['haproxy']

##
# config

if conf['enable_stats_socket']
  stats_socket = "#{conf['stats_socket_path']} user #{conf['stats_socket_user']} group #{conf['stats_socket_group']}"

  node.default['haproxy']['config']['global']['stats socket'] = stats_socket
end

if conf['enable_admin']
  node.default['haproxy']['config']['listen admin'] = conf['admin']['options']
  bind = "#{conf['admin']['address_bind']}:#{conf['admin']['port']}"
  node.default['haproxy']['config']['listen admin']['bind'] = bind
  node.default['haproxy']['config']['listen admin']['mode'] = :http
end

# for HTTP
if conf['enable_default_http']

  config_pool['frontend http'] = {
    maxconn: conf['frontend_max_connections'],
    bind: "#{conf['incoming_address']}:#{conf['incoming_port']}",
    default_backend: 'servers-http'
  }
end

cookie = nil
appsession = nil

if node['haproxy_part']['enable_sticky_session']
  case node['haproxy_part']['sticky_session_method'].to_sym
  when :cookie
    cookie = node['haproxy_part']['cookie']
  when :appsession
    appsession = node['haproxy_part']['appsession']
  end
end

# default backend (http)
if conf['enable_default_http'] || node['haproxy_part']['enable_ssl_proxy']

  servers_http = web_servers.map do |hostname, _server|
    sv = []
    sv << hostname
    sv << "#{primary_private_ip(hostname)}:#{conf['member_port']}"
    sv << 'weight 1'
    sv << "maxconn #{conf['member_max_connections']}"
    sv << 'check'

    sv << "cookie #{hostname}" unless cookie.nil? || cookie.empty?

    sv.join(' ')
  end

  options = []
  options << "httpchk #{conf['httpchk']}" if conf['httpchk']

  params = {
    server: servers_http,
    option: options
  }

  params['cookie'] = cookie unless cookie.nil? || cookie.empty?
  params['appsession'] = appsession unless appsession.nil? || appsession.empty?

  config_pool['backend servers-http'] = merge(node['haproxy_part']['backend_params'], params)

end

# for HTTPS
if conf['enable_ssl']

  config_pool['frontend https'] = {
    'maxconn' => conf['frontend_ssl_max_connections'],
    'bind' => "#{conf['ssl_incoming_address']}:#{conf['ssl_incoming_port']}",
    'default_backend' => 'servers-https'
  }

  servers_https = web_servers.map do |hostname, _server|
    sv = []
    sv << hostname
    sv << "#{primary_private_ip(hostname)}:#{conf['ssl_member_port']}"
    sv << 'weight 1'
    sv << "maxconn #{conf['member_max_connections']}"
    sv << 'check'

    sv << "cookie #{hostname}" unless cookie.nil? || cookie.empty?

    sv.join(' ')
  end

  options = ['ssl-hello-chk']
  options << "httpchk #{conf['ssl_httpchk']}" if conf['ssl_httpchk']

  params = {
    mode: :tcp,
    server: servers_https,
    option: options
  }

  params['cookie'] = cookie unless cookie.nil? || cookie.empty?
  params['appsession'] = appsession unless appsession.nil? || appsession.empty?

  config_pool['backend servers-https'] = merge(node['haproxy_part']['backend_params'], params)

else
  # SSL Proxy
  if node['haproxy_part']['enable_ssl_proxy']
    dir_path = "#{conf[conf['install_method']]['prefix']}#{node['haproxy_part']['ssl_pem_dir']}"

    directory dir_path do
      owner 'root'
      group 'root'
      mode  '0755'
    end

    file_path = "#{conf[conf['install_method']]['prefix']}#{node['haproxy_part']['ssl_pem_file']}"

    if node['haproxy_part']['pem_file']['protocol'] == 'remote'
      remote_file 'ssl_pem' do
        source node['haproxy_part']['pem_file']['remote']['url']
        path file_path
        owner 'root'
        group 'root'
        mode  '0644'
      end
    else
      haproxy_part_pem_file file_path
    end

    bind = "#{conf['ssl_incoming_address']}:#{conf['ssl_incoming_port']} ssl crt #{file_path}"

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
