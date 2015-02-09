template "#{node['pgpool_part']['config']['dir']}/pgpool.conf" do
  owner 'root'
  group 'root'
  mode '0764'
  notifies :restart, 'service[pgpool]', :delayed
end

service 'pgpool' do
  service_name node['pgpool_part']['service']
  action [:enable]
end
