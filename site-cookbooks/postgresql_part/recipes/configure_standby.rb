#
# Cookbook Name::postgresql_part
# Recipe:: configure_standby
#
#

ruby_block 'stop_postgresql' do
  block {}
  notifies :stop, 'service[postgresql]', :immediately
end

directory node['postgresql']['dir'] do
  action :delete
  recursive true
end

cmd_params = []
cmd_params << '-D'
cmd_params << node['postgresql']['dir']
cmd_params << '--xlog'
cmd_params << '--verbose'
cmd_params << '-h'
cmd_params << primary_db_ip
cmd_params << '-U'
cmd_params << 'replication'

code = "su - postgres -c '/usr/bin/pg_basebackup #{cmd_params.join(' ')}'"

bash 'pg_basebackup' do
  code code
end

file "#{node['postgresql']['dir']}/recovery.done" do
  action :delete
end

primary_conninfo = ["host=#{primary_db_ip} ",
                    "port=#{node['postgresql']['config']['port']} ",
                    "user=#{node['postgresql_part']['replication']['user']} ",
                    "password=#{generate_password('db_replication')}"].join

if node['postgresql']['config']['synchronous_commit'].is_a?(TrueClass) ||
   node['postgresql']['config']['synchronous_commit'] == 'on'
  primary_conninfo << " application_name=#{node['postgresql_part']['replication']['application_name']}"
end

node.set['postgresql_part']['recovery']['primary_conninfo'] = primary_conninfo

template "#{node['postgresql']['dir']}/recovery.conf" do
  source 'recovery.conf.erb'
  mode '0644'
  owner 'postgres'
  group 'postgres'
  notifies :start, 'service[postgresql]', :delayed
end

service 'postgresql' do
  service_name node['postgresql']['server']['service_name']
  supports [:restart, :reload, :status]
  action :nothing
end

# postgresql_part_append_service_tag 'standby'

service_info = consul_service_info('postgresql')

unless service_info.nil?
  service_info['Tags'] = [] if service_info['Tags'].nil?

  service_info['Tags'] << 'standby' unless service_info['Tags'].include? 'standby'

  cloudconductor_consul_service_def 'postgresql' do
    id service_info['ID']
    port service_info['Port']
    tags service_info['Tags']
    check service_info['Checks']
    action :nothing
  end
end
