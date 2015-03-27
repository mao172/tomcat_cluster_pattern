require_relative '../spec_helper'

describe 'postgresql_part::default' do
  let(:chef_run) { ChefSpec::SoloRunner.new }

  pgsql_version = '9.4'

  before do
    stub_command("ls /var/lib/pgsql/#{pgsql_version}/data/recovery.conf")
    chef_run.converge(described_recipe)
  end

  it 'include setup recipe' do
    stub_command('ls /var/lib/pgsql/9.3/data/recovery.conf')
    expect(chef_run).to include_recipe 'postgresql_part::setup'
  end
end
