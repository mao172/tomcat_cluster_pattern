require_relative '../spec_helper'

describe 'pgpool-II_part::setup' do
  let(:chef_run) { ChefSpec::SoloRunner.new }

  baseurl = 'http://example.com/rpms/'
  gpgkey = 'http://example.com/RPM-GPG-KEY-TEST'
  package_name = 'pgpool_paclage'
  group = 'test_group'
  user = 'test_user'
  service = 'pgpool'
  pgpool_dir = '/etc/pgpool'
  log_dir = '/var/log/pgpool'

  before do
    chef_run.node.set['pgpool_part']['repository']['baseurl'] = baseurl
    chef_run.node.set['pgpool_part']['repository']['gpgkey'] = gpgkey
    chef_run.node.set['pgpool_part']['package_name'] = package_name
    chef_run.node.set['pgpool_part']['group'] = group
    chef_run.node.set['pgpool_part']['user'] = user
    chef_run.node.set['pgpool_part']['service'] = service
    chef_run.node.set['pgpool_part']['config']['dir'] = pgpool_dir
    chef_run.node.set['pgpool_part']['pgconf']['logdir'] = log_dir

    chef_run.converge(described_recipe)
  end

  it 'create yum repository of pgpool' do
    expect(chef_run).to create_yum_repository('pgpool').with(
      baseurl: baseurl,
      gpgkey: gpgkey
    )
  end

  it 'install pgpool package' do
    expect(chef_run).to install_package(package_name)
  end

  it 'create postgres group' do
    expect(chef_run).to create_group(group)
  end

  it 'create postgres user' do
    expect(chef_run).to create_user(user).with(
      gid: group
    )
  end

  it 'create log directory' do
    expect(chef_run).to create_directory(log_dir).with(
      owner: user,
      group: group,
      mode: '0755'
    )
  end

  it 'create pool_passwd file' do
    expect(chef_run).to create_file_if_missing("#{pgpool_dir}/pool_passwd").with(
      owner: user,
      group: group
    )
  end

  it 'create pgpool_status file' do
    expect(chef_run).to create_file_if_missing("#{log_dir}/pgpool_status").with(
      owner: user,
      group: group
    )
  end

  it 'set enable service at root' do
    expect(chef_run).to enable_service('pgpool').with(
      service_name: service
    )
  end
end
