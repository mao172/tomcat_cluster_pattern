yum_repository 'pgpool' do
  description 'Pgpool-II Yum Repository provided by PgPool Global Development Group.'
  baseurl node['pgpool_part']['repository']['baseurl']
  gpgkey node['pgpool_part']['repository']['gpgkey']
  action :create
end

package node['pgpool_part']['package_name'] do
  action :install
end

group node['pgpool_part']['group'] do
  action :create
end

user node['pgpool_part']['user'] do
  action :create
  gid node['pgpool_part']['group']
end

directory node['pgpool_part']['pgconf']['logdir'] do
  action :create
  owner node['pgpool_part']['user']
  group node['pgpool_part']['group']
  mode '0755'
end

file "#{node['pgpool_part']['config']['dir']}/pool_passwd" do
  action :create_if_missing
  owner node['pgpool_part']['user']
  group node['pgpool_part']['group']
end

service 'pgpool' do
  service_name node['pgpool_part']['service']
  action [ :enable ]
end
