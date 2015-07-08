#
# Cookbook Name::postgresql_part
# Recipe:: register
#
#

service_info = consul_service_info('postgresql')
tag = primary_db?(node['ipaddress']) ? 'primary' : 'standby'

unless service_info.nil?
  service_info['Tags'] = [] if service_info['Tags'].nil?

  service_info['Tags'] << tag unless service_info['Tags'].include? tag

  cloudconductor_consul_service_def 'postgresql' do
    id service_info['ID']
    port service_info['Port']
    tags service_info['Tags']
    check service_info['Checks']
    action :create
  end
end
