if node['cloudconductor']['servers']
  db_servers = node['cloudconductor']['servers'].select { |_, s| s['roles'].include?('db') }
  node.set['tomcat_part']['database']['host'] = db_servers.map { |_, s| s['private_ip'] }.first
end

if node['tomcat_part']['pgpool2'] == true
  node.set['tomcat_part']['database']['host'] = 'localhost'
  node.set['tomcat_part']['database']['port'] = 9999
  node.set['tomcat_part']['session_db']['host'] = 'localhost'
  node.set['tomcat_part']['session_db']['port'] = 9999
end

applications = node['cloudconductor']['applications'].select { |_app_name, app| app['type'] == 'dynamic' }
applications.each do |app_name, app|
  case app['protocol']
  when 'git'
    deploy app_name do
      repo app['url']
      revision app['revision'] || 'HEAD'
      deploy_to node['tomcat']['webapp_dir']
      user node['tomcat']['user']
      group node['tomcat']['group']
      action :deploy
    end
  when 'http'
    remote_file app_name do
      source app['url']
      path File.join(node['tomcat']['webapp_dir'], "#{app_name}.war")
      mode '0644'
      owner node['tomcat']['user']
      group node['tomcat']['group']
    end
  end

  database_spec = {
    'type' => node['tomcat_part']['database']['type'],
    'name' => app_name,
    'user' => app_name,
    'host' => node['tomcat_part']['database']['host'],
    'port' => node['tomcat_part']['database']['port']
  }

  if node['tomcat_part']['session_replication'] == 'jdbcStore'
    tomcat_part_tables "#{app_name}_session" do
    end
  end

  tomcat_part_context "#{app_name}" do
    use_db true
    database database_spec
    sessionTableName "#{app_name}_session"
  end
end
