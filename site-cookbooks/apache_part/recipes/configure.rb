#
#

extend ApachePart::ModJkHelper

# determine the worker name　for mod_jk configuration
target_worker = worker_name

# set workers.properties
tomcat_servers = ap_servers.map do |hostname, server|
  {
    'name' => hostname,
    'host' => primary_private_ip(hostname),
    'route' => primary_private_ip(hostname),
    'weight' => server['weight'] || 1
  }
end

template "#{node['apache']['conf_dir']}/workers.properties" do
  source 'workers.properties.erb'
  mode '0664'
  owner node['apache']['user']
  group node['apache']['group']
  variables(
    worker_name: target_worker,
    tomcat_servers: tomcat_servers,
    sticky_session: node['apache_part']['sticky_session']
  )
  notifies :reload, 'service[apache2]', :delayed
end

service 'apache2' do
  service_name node['apache']['package']
  reload_command '/sbin/service httpd graceful'
  supports [:start, :restart, :reload, :status]
  action :nothing
end
