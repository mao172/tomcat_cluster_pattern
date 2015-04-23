require 'spec_helper'

describe port(5432) do
  it { should be_listening.with('tcp') }
end

describe 'postgresql server' do
  database = 'postgres'
  root_user = 'postgres'

  describe command("sudo -u postgres psql -U #{root_user} -d #{database} -c '\\l'") do
    its(:exit_status) { should eq 0 }
  end

  describe command("sudo -u postgres psql -U #{root_user} -d session -c '\\l'") do
    its(:exit_status) { should eq 0 }
  end

  describe command("sudo -u postgres psql -U #{root_user} -d application -c '\\l'") do
    its(:exit_status) { should eq 0 }
  end

  describe command("sudo -u postgres psql -U #{root_user} -d #{database} -c '\\dg' | grep tomcat") do
    its(:exit_status) { should eq 0 }
  end

  describe command("sudo -u postgres psql -U #{root_user} -d #{database} -c '\\dg' | grep application") do
    its(:exit_status) { should eq 0 }
  end

  describe command("sudo -u postgres psql -U #{root_user} -d #{database} -c '\\dg' | grep replication") do
    its(:exit_status) { should eq 0 }
  end

  describe command("sudo -u postgres psql -U #{root_user} -d #{database} -c '\\dg' | grep repcheck") do
    its(:exit_status) { should eq 0 }
  end
end
