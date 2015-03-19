#
# Cookbook Name:: pgpool-II_part
# Provider:: config_file
#

def whyrun_supported?
  true
end

use_inline_resources

action :create do
  file "#{node['pgpool_part']['config']['dir']}/pcp.conf" do
    owner 'root'
    group 'root'
    mode '0764'
    content "#{node['pgpool_part']['user']}:#{Digest::MD5.hexdigest(generate_password('pcp'))}"
  end

  template "#{node['pgpool_part']['config']['dir']}/pgpool.conf" do
    owner 'root'
    group 'root'
    mode '0764'
  end

  template "#{node['pgpool_part']['config']['dir']}/pool_hba.conf" do
    owner 'root'
    group 'root'
    mode '0764'
  end

  new_resource.updated_by_last_action(true)
end
