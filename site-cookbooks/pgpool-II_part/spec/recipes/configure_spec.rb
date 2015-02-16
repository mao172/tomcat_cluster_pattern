require_relative '../spec_helper'

describe 'pgpool-II_part::configure' do
  let(:chef_run) { ChefSpec::SoloRunner.new }

  pgpool_dir = '/etc/pgpool-II'

  before do
    chef_run.node.set['pgpool_part']['config']['dir'] = pgpool_dir
    chef_run.converge(described_recipe)
  end

  it 'create pgpool.conf and service restart' do
    expect(chef_run).to create_template("#{pgpool_dir}/pgpool.conf").with(
      owner: 'root',
      group: 'root',
      mode: '0764'
    )

    expect(chef_run.template("#{pgpool_dir}/pgpool.conf")).to notify('service[pgpool]').to(:restart).delayed
  end
end
