#
#

extend ApachePart::ModJkHelper

# determine the worker name　for mod_jk configuration
target_worker = worker_name

applications = node['cloudconductor']['applications'].select { |_app_name, app| app['type'] == 'dynamic' }

# set uriworkers.properties
template "#{node['apache']['conf_dir']}/uriworkermap.properties" do
  source 'uriworkermap.properties.erb'
  mode '0664'
  owner node['apache']['user']
  group node['apache']['group']
  variables(
    worker_name: target_worker,
    app_name: applications.first.first
  )
  notifies :reload, 'service[apache2]', :delayed
end

service 'apache2' do
  service_name node['apache']['package']
  reload_command '/sbin/service httpd graceful'
  supports [:start, :restart, :reload, :status]
  action :nothing
end
