require 'spec_helper'

describe port(5432) do
  it { should be_listening.with('tcp') }
end

describe 'postgresql server' do
  hostname = '127.0.0.1'
  port = '5432'
  database = 'postgres'
  root_user = 'postgres'

  params = property[:consul_parameters]

  if params[:postgresql] && params[:postgresql]['password'] && params[:postgresql]['password']['postgres']
    root_passwd = params[:postgresql]['password']['postgres']
  else
    root_passwd = 'todo_replace_random_password'
  end

  describe command("sudo -u postgres psql -U #{root_user} -d #{database} -c '\\l'") do
    its(:exit_status) { should eq 0 }
  end
end
