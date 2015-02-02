require_relative '../spec_helper'

describe 'tomcat_part::deploy' do
  let(:chef_run) { ChefSpec::SoloRunner.new(step_into: %w(tomcat_part_context tomcat_part_tables)) }

  app_name = 'application'
  db_private_ip = '172.0.0.10'

  before do
    chef_run.node.set['cloudconductor']['servers'] = {
      db: {
        roles: 'db',
        private_ip: db_private_ip
      }
    }
    chef_run.node.set['cloudconductor']['applications'] = {
      app_name => {}
    }
    chef_run.converge(described_recipe)
  end

  describe 'dynamic type applications are included in "cloudconductor applications"' do
    before do
      chef_run.node.set['cloudconductor']['applications'] = {
        app_name => {
          type: 'dynamic'
        }
      }
      chef_run.converge(described_recipe)
    end

    describe 'application deploy protocol is git' do
      it 'application deploy from git' do
        git_url = 'https://github.com/cloudconductor/cloud_conductor.git'
        git_version = '0.3'
        tomcat_user = 'tomcat'
        tomcat_group = 'passwd'
        tomcat_webapp_dir = '/var/lib/tomcat7/webapps'

        chef_run.node.set['cloudconductor']['applications'][app_name]['protocol'] = 'git'
        chef_run.node.set['cloudconductor']['applications'][app_name]['url'] = git_url
        chef_run.node.set['cloudconductor']['applications'][app_name]['revision'] = git_version
        chef_run.node.set['tomcat']['user'] = tomcat_user
        chef_run.node.set['tomcat']['group'] = tomcat_group
        chef_run.node.set['tomcat']['webapp_dir'] = tomcat_webapp_dir
        chef_run.converge(described_recipe)

        expect(chef_run).to deploy_deploy(app_name).with(
          repo: git_url,
          revision: git_version,
          deploy_to: tomcat_webapp_dir,
          user: tomcat_user,
          group: tomcat_group
        )
      end
    end
    describe 'application deploy protocol is http' do
      it 'application download from git' do
        url = 'http://cloudconductor.org/application.war'
        tomcat_user = 'tomcat'
        tomcat_group = 'passwd'
        tomcat_webapp_dir = '/var/lib/tomcat7/webapps'
        chef_run.node.set['cloudconductor']['applications'][app_name]['protocol'] = 'http'
        chef_run.node.set['cloudconductor']['applications'][app_name]['url'] = url
        chef_run.node.set['tomcat']['user'] = tomcat_user
        chef_run.node.set['tomcat']['group'] = tomcat_group
        chef_run.node.set['tomcat']['webapp_dir'] = tomcat_webapp_dir
        chef_run.converge(described_recipe)

        expect(chef_run).to create_remote_file(app_name).with(
          source: url,
          path: "#{tomcat_webapp_dir}/#{app_name}.war",
          mode: '0644',
          owner: tomcat_user,
          group: tomcat_group
        )
      end
    end

    describe 'create context xml' do
      tomcat_user = 'tomcat'
      tomcat_group = 'passwd'
      context_dir = '/etc/tomcat7/Catalina/localhost'
      db_settings = {
        'type' => 'postgresql',
        'name' => 'application',
        'user' => 'application',
        'host' => db_private_ip,
        'port' => 5432
      }
      data_source = 'jdbc/test'

      describe 'when not using session replication' do
        before do
          db_settings['host'] = db_private_ip
          db_settings['port'] = 5432

          chef_run.node.set['tomcat']['user'] = tomcat_user
          chef_run.node.set['tomcat']['group'] = tomcat_group
          chef_run.node.set['tomcat']['context_dir'] = context_dir
          chef_run.node.set['tomcat_part']['database'] = db_settings
          chef_run.node.set['tomcat_part']['datasource'] = data_source
          chef_run.node.set['tomcat_part']['session_replication'] = 'none'
          chef_run.node.set['tomcat_part']['pgpool2'] = false
          chef_run.converge(described_recipe)
        end

        it 'and not using pgpool-II' do
          expect(chef_run).to create_template("#{context_dir}/#{app_name}.xml").with(
            source: 'context.xml.erb',
            mode: '0644',
            owner: tomcat_user,
            group: tomcat_group,
            variables: hash_including(
              database: db_settings,
              password: /[0-9a-f]{32}/,
              datasource: data_source
            )
          )
        end

        it 'and using pgpool-II ' do
          chef_run.node.set['tomcat_part']['session_replication'] = 'none'
          chef_run.node.set['tomcat_part']['pgpool2'] = true
          chef_run.converge(described_recipe)

          db_settings['host'] = 'localhost'
          db_settings['port'] = 9999

          expect(chef_run).to create_template("#{context_dir}/#{app_name}.xml").with(
            source: 'context.xml.erb',
            mode: '0644',
            owner: tomcat_user,
            group: tomcat_group,
            variables: hash_including(
              database: db_settings,
              password: /[0-9a-f]{32}/,
              datasource: data_source
            )
          )
        end

        it 'not create tables.sql' do
          expect(chef_run).to_not create_template("#{Chef::Config[:file_cache_path]}/#{app_name}_session_createtable.sql")
        end
      end

      describe 'with session replication at JDBCStore' do
        session_db = {
          'dataSourceName' => 'jdbc/test_session',
          'type' => 'postgresql',
          'name' => 'application',
          'user' => 'application',
          'password' => 'pswd',
          'host' => db_private_ip,
          'port' => 5432
        }
        session_table_name = 'tomcat$session'
        session_table = {
          'name' => session_table_name,
          'idCol' => 'id',
          'appCol' => 'app',
          'dataCol' => 'data',
          'lastAccessedCol' => 'lastAccess',
          'maxInactiveCol' => 'maxInactive',
          'validCol' => 'valid'
        }

        before do
          db_settings['host'] = db_private_ip
          db_settings['port'] = 5432

          session_db['host'] = db_private_ip
          session_db['port'] = 5432
          session_db['password'] = 'pswd'

          chef_run.node.set['tomcat']['user'] = tomcat_user
          chef_run.node.set['tomcat']['group'] = tomcat_group
          chef_run.node.set['tomcat']['context_dir'] = context_dir
          chef_run.node.set['tomcat_part']['database'] = db_settings
          chef_run.node.set['tomcat_part']['datasource'] = data_source
          chef_run.node.set['tomcat_part']['session_replication'] = 'jdbcStore'
          chef_run.node.set['tomcat_part']['session_db'] = session_db
          chef_run.node.set['tomcat_part']['session_table'] = session_table
          chef_run.node.set['tomcat_part']['pgpool2'] = false
          chef_run.converge(described_recipe)
        end

        it 'when not using pgpool-II' do
          session_table['name'] = "#{app_name}_session"
          session_db['password'] = /[0-9a-f]{32}/

          expect(chef_run).to create_template("#{context_dir}/#{app_name}.xml").with(
            source: 'jdbcstore/context.xml.erb',
            mode: '0644',
            owner: tomcat_user,
            group: tomcat_group,
            variables: hash_including(
              use_db: true,
              use_jndi: true,
              database: db_settings,
              password: /[0-9a-f]{32}/,
              datasource: data_source,
              session_db: session_db,
              session_table: session_table
            )
          )
        end

        it 'when using pgpool-II' do
          chef_run.node.set['tomcat_part']['pgpool2'] = true
          chef_run.converge(described_recipe)

          db_settings['host'] = 'localhost'
          db_settings['port'] = 9999

          session_db['host'] = 'localhost'
          session_db['port'] = 9999
          session_db['password'] = /[0-9a-f]{32}/

          session_table['name'] = "#{app_name}_session"

          expect(chef_run).to create_template("#{context_dir}/#{app_name}.xml").with(
            source: 'jdbcstore/context.xml.erb',
            mode: '0644',
            owner: tomcat_user,
            group: tomcat_group,
            variables: hash_including(
              use_db: true,
              use_jndi: true,
              database: db_settings,
              password: /[0-9a-f]{32}/,
              datasource: data_source,
              session_db: session_db,
              session_table: session_table
            )
          )
        end
      end
    end

    describe 'create tables for JDBCStore' do
      tomcat_user = 'tomcat'
      tomcat_group = 'passwd'
      context_dir = '/etc/tomcat7/Catalina/localhost'
      db_settings = {
        'type' => 'postgresql',
        'name' => 'application',
        'user' => 'application',
        'password' => 'pass',
        'host' => db_private_ip,
        'port' => 5432
      }
      data_source = 'jdbc/test'

      session_db = {
        'dataSourceName' => 'jdbc/test_session',
        'type' => 'postgresql',
        'name' => 'application',
        'user' => 'application',
        'password' => 'pass',
        'host' => db_private_ip,
        'port' => 5432
      }
      session_table_name = 'tomcat$session'
      session_table = {
        'name' => session_table_name,
        'idCol' => 'id',
        'appCol' => 'app',
        'dataCol' => 'data',
        'lastAccessedCol' => 'lastAccess',
        'maxInactiveCol' => 'maxInactive',
        'validCol' => 'valid'
      }

      before do
        chef_run.node.set['tomcat']['user'] = tomcat_user
        chef_run.node.set['tomcat']['group'] = tomcat_group
        chef_run.node.set['tomcat']['context_dir'] = context_dir
        chef_run.node.set['tomcat_part']['database'] = db_settings
        chef_run.node.set['tomcat_part']['datasource'] = data_source
        chef_run.node.set['tomcat_part']['session_replication'] = 'jdbcStore'
        chef_run.node.set['tomcat_part']['session_db'] = session_db
        chef_run.node.set['tomcat_part']['session_table'] = session_table
        chef_run.node.set['tomcat_part']['pgpool2'] = false
        chef_run.converge(described_recipe)
      end

      it 'create tables.sql file' do
        session_table['name'] = "#{app_name}_session"

        expect(chef_run).to create_template("#{Chef::Config[:file_cache_path]}/#{app_name}_session_createtable.sql").with(
          source: 'jdbcstore/tables.sql.erb',
          mode: '0644',
          variables: {
            database_type: session_db['type'],
            session_table: session_table
          }
        )
      end

      it 'database exec query' do
        database_name = session_db['name']

        expect(chef_run).to ChefSpec::Matchers::ResourceMatcher.new(
          :database,
          :query,
          database_name
        )
      end
    end
  end

  describe 'multiple dynamic type applications are included in "cloudconductor applications"' do
    app2_name = 'app2'
    before do
      chef_run.node.set['cloudconductor']['applications'] = {
        app_name => {
          type: 'dynamic'
        },
        app2_name => {
          type: 'dynamic'
        }
      }
      chef_run.converge(described_recipe)
    end
    it 'download of all applications' do
      chef_run.node.set['cloudconductor']['applications'][app_name]['protocol'] = 'git'
      chef_run.node.set['cloudconductor']['applications'][app2_name]['protocol'] = 'git'
      chef_run.converge(described_recipe)

      expect(chef_run).to deploy_deploy(app_name)
      expect(chef_run).to deploy_deploy(app2_name)
    end
    it 'create all applications context xml' do
      context_dir = '/etc/tomcat7/Catalina/localhost'
      chef_run.node.set['tomcat']['context_dir'] = context_dir
      chef_run.converge(described_recipe)

      expect(chef_run).to create_template("#{context_dir}/#{app_name}.xml")
      expect(chef_run).to create_template("#{context_dir}/#{app2_name}.xml")
    end

    it 'create all applications tables.sql file' do
      chef_run.node.set['tomcat_part']['session_replication'] = 'jdbcStore'
      chef_run.converge(described_recipe)

      expect(chef_run).to create_template("#{Chef::Config[:file_cache_path]}/#{app_name}_session_createtable.sql")
      expect(chef_run).to create_template("#{Chef::Config[:file_cache_path]}/#{app2_name}_session_createtable.sql")
    end
  end

  describe 'static type applications as not included in "cloudconductor applications"' do
    before do
      chef_run.node.set['cloudconductor']['applications'] = {
        app_name => {
          type: 'statis'
        }
      }
      chef_run.converge(described_recipe)
    end
    it 'not download of applications' do
      chef_run.node.set['cloudconductor']['applications'][app_name]['protocol'] = 'git'
      chef_run.converge(described_recipe)

      expect(chef_run).to_not deploy_deploy(app_name)
    end
    it 'not create  context xml' do
      context_dir = '/etc/tomcat7/Catalina/localhost'
      chef_run.node.set['tomcat']['context_dir'] = context_dir
      chef_run.converge(described_recipe)

      expect(chef_run).to_not create_template("#{context_dir}/#{app_name}.xml")
    end

    it 'not create tables.sql' do
      expect(chef_run).to_not create_template("#{Chef::Config[:file_cache_path]}/#{app_name}_session_createtable.sql")
    end
  end
end
