#
# Cookbook Name:: tomcat_part
# Recipe:: setup
#

yum_repository 'jpackage' do
  description 'JPackage 6 generic'
  mirrorlist 'http://www.jpackage.org/mirrorlist.php?dist=generic&type=free&release=6.0'
  gpgcheck false
  action :create
  only_if { platform_family?('rhel') && node['tomcat_part']['use_jpackage'] }
end

include_recipe 'tomcat'

# Install JDBC Driver
database_type = node['tomcat_part']['database']['type']
driver_url = node['tomcat_part']['jdbc'][database_type]
filename = File.basename(driver_url)

case filename
when /.*\.tar\.gz$/
  remote_file "#{Chef::Config[:file_cache_path]}/#{filename}" do
    source driver_url
  end

  bash 'extract_jdbc_driver' do
    code "tar -zxvf #{Chef::Config[:file_cache_path]}/#{filename} -C #{node['tomcat']['home']}/lib"
  end
else
  remote_file "#{node['tomcat']['home']}/lib/#{filename}" do
    source driver_url
  end
end

bash 'chown_tomcat_home' do
  code "chown #{node['tomcat']['user']}:#{node['tomcat']['group']} #{node['tomcat']['home']}"
end

# Install PostgreSQL-Client
if node['tomcat_part']['database']['type'] == 'postgresql'
  include_recipe 'postgresql::client'
  include_recipe 'postgresql::ruby'

end

# Configuration for session replication.
case node['tomcat_part']['session_replication']
when 'jdbcStore'
  bash 'modify_catalina_properties' do
    not_if <<-EOF
grep "org.apache.catalina.STRICT_SERVLET_COMPLIANCE" #{node['tomcat']['home']}/conf/catalina.properties
EOF
    code <<-EOF
echo "org.apache.catalina.STRICT_SERVLET_COMPLIANCE=true" >> #{node['tomcat']['home']}/conf/catalina.properties
EOF
  end
end
