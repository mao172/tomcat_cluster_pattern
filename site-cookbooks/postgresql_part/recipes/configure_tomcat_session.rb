#
# Cookbook Name:: tomcat_cluster_pattern
# Recipe:: configure_tomcat_session
#

::Chef::Recipe.send(:include, DbHelper)

if primary_db?(node[:ipaddress])

  postgresql_connection_info = {
    host: '127.0.0.1',
    port: node['postgresql']['config']['port'],
    username: 'postgres',
    password: node['postgresql']['password']['postgres']
  }

  # create session db
  #

  postgresql_database_user node['postgresql_part']['tomcat_session']['user'] do
    connection postgresql_connection_info
    password generate_password(node['postgresql_part']['tomcat_session']['password'])
    action :create
  end

  postgresql_database node['postgresql_part']['tomcat_session']['database'] do
    connection postgresql_connection_info
    owner node['postgresql_part']['tomcat_session']['user']
    action :create
  end

end
