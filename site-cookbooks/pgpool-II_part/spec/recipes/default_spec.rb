require_relative '../spec_helper'

describe 'pgpool-II_part::default' do
  let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

  it 'include setup recipe' do
    expect(chef_run).to include_recipe 'pgpool-II_part::setup'
  end
end
