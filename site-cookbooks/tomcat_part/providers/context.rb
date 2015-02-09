action :create do
  %w(session_replication use_jndi use_db datasource database session_db session_table).each do |attr|
    unless new_resource.instance_variable_get("@#{attr}")
      new_resource.instance_variable_set("@#{attr}", node['tomcat_part'][attr])
    end
  end

  app_name = new_resource.app_name

  case new_resource.session_replication
  when 'jdbcStore' then

    session_table = {
      'name'     => new_resource.sessionTableName,
      'idCol'    => new_resource.session_table.idCol,
      'appCol'   => new_resource.session_table.appCol,
      'dataCol'  => new_resource.session_table.dataCol,
      'lastAccessedCol'   => new_resource.session_table.lastAccessedCol,
      'maxInactiveCol'    => new_resource.session_table.maxInactiveCol,
      'validCol' => new_resource.session_table.validCol
    }

    template "#{node['tomcat']['context_dir']}/#{app_name}.xml" do
      source 'jdbcstore/context.xml.erb'
      mode '0644'
      owner node['tomcat']['user']
      group node['tomcat']['group']
      variables(
        use_db: new_resource.use_db,
        use_jndi: new_resource.use_jndi,
        database: new_resource.database,
        password: generate_password('database'),
        datasource: new_resource.datasource,
        session_db: new_resource.session_db,
        session_table: session_table
      )
    end

  else

    template "#{node['tomcat']['context_dir']}/#{app_name}.xml" do
      source 'context.xml.erb'
      mode '0644'
      owner node['tomcat']['user']
      group node['tomcat']['group']
      variables(
        database: new_resource.database,
        password: generate_password('database'),
        datasource: new_resource.datasource
      )
    end
  end
end
