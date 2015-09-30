#
# Cookbook Name:: tomcat_part
# Provider:: table
#

def whyrun_supported?
  true
end

use_inline_resources

action :create do
  %w(session_db session_table).each do |attr|
    unless new_resource.instance_variable_get("@#{attr}")
      new_resource.instance_variable_set("@#{attr}", node['tomcat_part'][attr])
    end
  end

  tbl_name = new_resource.table_name

  session_table = {
    'name' => tbl_name,
    'idCol' => new_resource.session_table['idCol'],
    'appCol' => new_resource.session_table['appCol'],
    'dataCol' => new_resource.session_table['dataCol'],
    'lastAccessedCol' => new_resource.session_table['lastAccessedCol'],
    'maxInactiveCol' => new_resource.session_table['maxInactiveCol'],
    'validCol' => new_resource.session_table['validCol']
  }

  template "#{Chef::Config[:file_cache_path]}/#{tbl_name}_createtable.sql" do
    source 'jdbcstore/tables.sql.erb'
    mode '0644'
    #    owner node['postgresql']['user']
    #    group node['postgresql']['group']
    variables(
      database_type: new_resource.session_db.type,
      session_table: session_table
    )
  end

  database_spec = {
    host: new_resource.session_db['host'],
    port: new_resource.session_db['port'],
    username: new_resource.session_db['user'],
    password: new_resource.session_db['password']
  }

  case new_resource.session_db['type']
  when 'postgresql'
    provider = Chef::Provider::Database::Postgresql
  when 'mysql'
    provider = Chef::Provider::Database::Mysql
  when 'oracle'
    provider = Chef::Provider::Database::Oracle
  end

  database new_resource.session_db['name'] do
    connection database_spec
    provider provider
    sql lazy { ::File.read("#{Chef::Config[:file_cache_path]}/#{tbl_name}_createtable.sql") }
    action :query
  end

  new_resource.updated_by_last_action(true)
end
