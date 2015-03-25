if node['cloudconductor']['servers']
  db_servers = node['cloudconductor']['servers'].select { |_, s| s['roles'].include?('db') }
  node.set['tomcat_part']['database']['host'] = db_servers.map { |_, s| s['private_ip'] }.first

  ap_servers = node['cloudconductor']['servers'].select { |_, s| s['roles'].include?('ap') }
end

if node['tomcat_part']['pgpool2'] == true
  node.set['tomcat_part']['database']['host'] = 'localhost'
  node.set['tomcat_part']['database']['port'] = 9999
  node.set['tomcat_part']['session_db']['host'] = 'localhost'
  node.set['tomcat_part']['session_db']['port'] = 9999
end

if node['tomcat_part']['session_replication'] == 'jdbcStore'
  pswd_key = node['tomcat_part']['session_db']['password']
  node.set['tomcat_part']['session_db']['password'] = generate_password(pswd_key)
end

applications = node['cloudconductor']['applications'].select { |_app_name, app| app['type'] == 'dynamic' }
applications.each do |app_name, app|
  case app['protocol']
  when 'git'
    source_path = File.join(Dir.tmpdir, "#{app_name}")

    deploy app_name do
      repo app['url']
      revision app['revision'] || 'HEAD'
      deploy_to source_path
      user node['tomcat']['user']
      group node['tomcat']['group']
      action :deploy
    end
  when 'http'
    source_path = File.join(Dir.tmpdir, "#{app_name}.war")

    remote_file app_name do
      source app['url']
      path source_path
      mode '0644'
      owner node['tomcat']['user']
      group node['tomcat']['group']
    end
  end

  bash app_name do
    code "mv #{source_path} #{node['tomcat']['webapp_dir']}"
  end

  database_spec = {
    'type' => node['tomcat_part']['database']['type'],
    'name' => node['tomcat_part']['database']['name'],
    'user' => node['tomcat_part']['database']['user'],
    'host' => node['tomcat_part']['database']['host'],
    'port' => node['tomcat_part']['database']['port']
  }

  if node['tomcat_part']['session_replication'] == 'jdbcStore'
    tomcat_part_tables "#{app_name}_session" do
      only_if { ap_servers.map { |_, s| s['private_ip'] }.first == node['ipaddress'] }
    end
  end

  tomcat_part_context "#{app_name}" do
    use_db true
    database database_spec
    sessionTableName "#{app_name}_session"
  end
end
