#
#

require_relative '../spec_helper'

describe 'haproxy_part::setup' do
  let(:chef_run) { ChefSpec::SoloRunner.new }

  before do
    chef_run.node.set[:haproxy_part][:rsyslog][:setup] = false
    chef_run.converge(described_recipe)
  end

  it 'include default recipe of haproxy cookbook' do
    expect(chef_run).to include_recipe('haproxy::default')
  end

  it 'include default recipe of rsyslog cookbook' do
    chef_run.node.set[:haproxy_part][:rsyslog][:config] = true
    chef_run.node.set[:haproxy_part][:rsyslog][:setup] = true

    chef_run.converge(described_recipe)

    expect(chef_run).to include_recipe('rsyslog::default')
  end

  it 'exclude recipe of rsyslog cookbook' do
    chef_run.node.set[:haproxy_part][:rsyslog][:config] = true
    chef_run.node.set[:haproxy_part][:rsyslog][:setup] = false

    chef_run.converge(described_recipe)

    expect(chef_run).to_not include_recipe('rsyslog::default')
  end

  it 'create haproxy.conf for rsyslog' do
    chef_run.node.set[:haproxy_part][:rsyslog][:config] = true
    # chef_run.node.set[:haproxy_part][:rsyslog][:setup] = true

    chef_run.converge(described_recipe)

    file_path = "#{chef_run.node['rsyslog']['config_prefix']}/rsyslog.d/20-haproxy.conf"

    expect(chef_run).to create_template(file_path).with(
      source: 'rsyslog-haproxy.conf.erb',
      owner:  'root',
      group:  'root',
      mode:   '0644'
    )
  end

  it 'not create haproxy.conf for rsyslog' do
    chef_run.node.set[:haproxy_part][:rsyslog][:config] = false
    # chef_run.node.set[:haproxy_part][:rsyslog][:setup] = true

    chef_run.converge(described_recipe)

    file_path = "#{chef_run.node['rsyslog']['config_prefix']}/rsyslog.d/20-haproxy.conf"

    expect(chef_run).to_not create_template(file_path)
  end
end
