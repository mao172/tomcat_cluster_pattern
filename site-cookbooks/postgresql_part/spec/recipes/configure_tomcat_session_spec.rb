require_relative '../spec_helper'
require 'chefspec'

describe 'postgresql_part::configure_tomcat_session' do
  let(:chef_run) { ChefSpec::SoloRunner.new }

  localhost = '127.0.0.1'
  db_port = 5432
  db_user = 'postgres'
  db_pswd = 'postgres_pswd'

  postgresql_connection_info = {
    host: localhost,
    port: db_port,
    username: db_user,
    password: db_pswd
  }

  tomcat_user = 'tomcat_usr'
  tomcat_db = 'tomcat_session_db'

  generate_pswd = 'generate_pswd'

  before do
    chef_run.node.set['postgresql']['config']['port'] = db_port
    chef_run.node.set['postgresql']['password']['postgres'] = db_pswd

    chef_run.node.set['postgresql_part']['tomcat_session']['user'] = tomcat_user
    chef_run.node.set['postgresql_part']['tomcat_session']['database'] = tomcat_db

    allow_any_instance_of(Chef::Recipe).to receive(:is_primary_db?).and_return(true)

    chef_run.converge(described_recipe)

    allow_any_instance_of(Chef::Resource)
      .to receive(:generate_password).with('tomcat').and_return(generate_pswd)

    chef_run.converge(described_recipe)
  end

  def create_postgresql_database_user(name)
    ChefSpec::Matchers::ResourceMatcher.new(
      :postgresql_database_user,
      :create,
      name
    )
  end

  it 'create tomcat session user' do
    expect(chef_run).to create_postgresql_database_user(tomcat_user).with(
      connection: postgresql_connection_info,
      password: generate_pswd
    )
  end

  def create_postgresql_database(name)
    ChefSpec::Matchers::ResourceMatcher.new(
      :postgresql_database,
      :create,
      name
    )
  end

  it 'create tomcat session database' do
    expect(chef_run).to create_postgresql_database(tomcat_db).with(
      connection: postgresql_connection_info,
      owner: tomcat_user
    )
  end
end
