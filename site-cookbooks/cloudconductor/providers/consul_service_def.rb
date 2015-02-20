#
# Cookbook Name:: cloudconductor
# Providers:: consul_service_def
#
#

require 'json'

use_inline_resources

action :create do
  ConsulClient.regist_service(
    name: new_resource.name,
    id: new_resource.id,
    port: new_resource.port,
    tags: new_resource.tags,
    check: new_resource.check
  )

  file new_resource.path do
    user new_resource.user
    group new_resource.group
    mode 0600
    content new_resource.to_json
    action :create
  end
end

action :delete do
  CloudConductor::ConsulClient.remove_service new_resource.name

  file new_resource.path do
    action :delete
  end
end
