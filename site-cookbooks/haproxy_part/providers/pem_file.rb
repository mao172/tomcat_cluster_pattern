#
# Cookbook Name:: haproxy_part
# Provider:: pem_file
#
#

# require 'cloud_conductor_utils/consul'

def read_pem_resource_from_consul
  Chef::Log.info("read pem from consul [key: #{node[:haproxy_part][:pem_file][:consul][:key]}]")

  key = node[:haproxy_part][:pem_file][:consul][:key]
  type = node[:haproxy_part][:pem_file][:consul][:value_type].to_sym

  ret = ConsulUtils.get_value(key, type)

  if node[:haproxy_part][:pem_file][:property_nm]
    prop = node[:haproxy_part][:pem_file][:property_nm]
    ret = ret[prop]
  end

  ret
end

def read_pem_resource_from_file
  Chef::Log.info("read pem file : #{node[:haproxy_part][:pem_file][:uri]}")
  ::File.read(node[:haproxy_part][:pem_file][:uri])
end

def read_pem
  case node[:haproxy_part][:pem_file][:protocol].to_sym
  when :consul
    src = read_pem_resource_from_consul
  when :local
    src = read_pem_resource_from_file
  end

  src
end

action :create do
  Chef::Log.info("Provider:: pem_file, Action:: :create ")
  pem_source = read_pem

  Chef::Log.debug(pem_source)

  raise 'SSL server certificate could not be retrieved.' if pem_source.nil? || pem_source.empty?

  file new_resource.file_name do
    content  pem_source
    owner 'root'
    group 'root'
    mode  '0644'
    action :create
  end
end
