require_relative '../spec_helper'

describe 'backup_restore::restore' do
  let(:chef_run) do
    runner = ChefSpec::SoloRunner.new(
      cookbook_path: %w(site-cookbooks cookbooks),
      platform:      'centos',
      version:       '6.5'
    )do |node|
      node.set['backup_restore']['destinations']['enabled'] = %w(s3)
      node.set['backup_restore']['destinations']['s3'] = {
        bucket: 's3bucket',
        access_key_id: 'access_key_id',
        secret_access_key: 'secret_access_key',
        region: 'us-east-1',
        prefix: '/backup'
      }
      node.set['backup_restore']['restore']['target_sources'] = %w(postgresql)
    end

    runner.converge(described_recipe)
  end

  before do
    stub_command('/usr/bin/s3cmd').and_return(true)
    expect_any_instance_of(Chef::Recipe).to receive(:`).and_return('s3://s3bucket/backup/directory_full/2014.10.01.00.00.00')
  end

  it 'create temporary directory' do
    expect(chef_run).to create_directory('/tmp/backup/restore').with(
      recursive: true
    )
  end

  it 'run directory backup' do
    expect(chef_run).to include_recipe('backup_restore::fetch_s3')
  end

  it 'run directory backup' do
    expect(chef_run).to include_recipe('backup_restore::restore_postgresql')
  end

  it 'delete temporary directory' do
    expect(chef_run).to delete_directory('/tmp/backup/restore').with(
      recursive: true
    )
  end
end
