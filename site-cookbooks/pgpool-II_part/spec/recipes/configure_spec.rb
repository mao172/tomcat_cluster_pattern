require_relative '../spec_helper'

describe 'pgpool-II_part::configure' do
  let(:chef_run) { ChefSpec::SoloRunner.new }

  pgpool_dir = '/etc/pgpool-II'

  before do
    chef_run.node.set['pgpool_part']['user'] = 'postgres'
    chef_run.node.set['pgpool_part']['config']['dir'] = pgpool_dir
    chef_run.node.set['pgpool_part']['postgresql']['dir'] = '/var/lib/pgsql/9.4/data'
    chef_run.node.set['pgpool_part']['postgresql']['port'] = '5432'
    chef_run.node.set['pgpool_part']['pgconf']['port'] = 9999
    chef_run.node.set['pgpool_part']['pgconf']['backend_flag0'] = 'ALLOW_TO_FAILOVER'
    chef_run.node.set['pgpool_part']['pgconf']['backend_weight0'] = 1
    chef_run.node.set['pgpool_part']['pgconf']['wd_port'] = 9000
    chef_run.node.set['pgpool_part']['pgconf']['wd_heartbeat_port'] = 9694
    chef_run.node.set['cloudconductor']['servers'] = {
      'db1' => { 'roles' => 'db', 'private_ip' => '127.0.0.1' },
      'ap1' => { 'roles' => 'ap', 'private_ip' => '127.0.0.101' }
    }
    chef_run.node.automatic_attrs['ipaddress'] = '127.0.0.101'
    chef_run.converge(described_recipe)
  end

  it 'create pcp.conf, to write pcp user and password hash, and service restart' do
    allow_any_instance_of(Chef::Resource).to receive(:generate_password).with('pcp').and_return('foobarbaz')
    allow(Digest::MD5).to receive(:hexdigest).with('foobarbaz').and_return('dummy_passwd')
    chef_run.converge(described_recipe)

    expect(chef_run).to create_file("#{pgpool_dir}/pcp.conf").with(
      owner: 'root',
      group: 'root',
      mode: '0764',
      content: 'postgres:dummy_passwd'
    )

    expect(chef_run.file("#{pgpool_dir}/pcp.conf")).to notify('service[pgpool]').to(:restart).delayed
  end

  it 'create pgpool.conf and service restart' do
    expect(chef_run).to create_template("#{pgpool_dir}/pgpool.conf").with(
      owner: 'root',
      group: 'root',
      mode: '0764'
    )

    expect(chef_run.template("#{pgpool_dir}/pgpool.conf")).to notify('service[pgpool]').to(:restart).delayed
  end

  it 'write the backend db settings to pgpool.conf' do
    expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf").with_content(/#{"backend_hostname0".ljust(25)} = '127.0.0.1'/)
    expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf").with_content(/#{"backend_port0".ljust(25)} = '5432'/)
    expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf").with_content(/#{"backend_weight0".ljust(25)} = 1/)
    expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf")
      .with_content(/#{"backend_data_directory0".ljust(25)} = '\/var\/lib\/pgsql\/9.4\/data'/)
    expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf")
      .with_content(/#{"backend_flag0".ljust(25)} = 'ALLOW_TO_FAILOVER'/)
  end

  describe 'db node there are multiple' do
    before do
      chef_run.node.set['cloudconductor']['servers'] = {
        'foo' => { 'roles' => 'db', 'private_ip' => '127.0.0.1' },
        'bar' => { 'roles' => 'db', 'private_ip' => '127.0.0.2' }
      }
      chef_run.converge(described_recipe)
    end

    it 'backend_flag1 or later is the same value as the backend_flag0' do
      expect(chef_run.node['pgpool_part']['pgconf']['backend_flag1'])
        .to eq(chef_run.node['pgpool_part']['pgconf']['backend_flag0'])
    end

    it 'backend_weight1 or later is the same value as the backend_weight0' do
      expect(chef_run.node['pgpool_part']['pgconf']['backend_weight1'])
        .to eq(chef_run.node['pgpool_part']['pgconf']['backend_weight0'])
    end

    it 'write to pgpool.conf all of the nodes as a backend' do
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf").with_content(/#{"backend_hostname0".ljust(25)} = '127.0.0.1'/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf").with_content(/#{"backend_port0".ljust(25)} = '5432'/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf").with_content(/#{"backend_weight0".ljust(25)} = 1/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf")
        .with_content(/#{"backend_data_directory0".ljust(25)} = '\/var\/lib\/pgsql\/9.4\/data'/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf")
        .with_content(/#{"backend_flag0".ljust(25)} = 'ALLOW_TO_FAILOVER'/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf").with_content(/#{"backend_hostname1".ljust(25)} = '127.0.0.2'/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf").with_content(/#{"backend_port1".ljust(25)} = '5432'/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf").with_content(/#{"backend_weight1".ljust(25)} = 1/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf")
        .with_content(/#{"backend_data_directory1".ljust(25)} = '\/var\/lib\/pgsql\/9.4\/data'/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf")
        .with_content(/#{"backend_flag1".ljust(25)} = 'ALLOW_TO_FAILOVER'/)
    end
  end

  describe 'node of ap role is own node only' do
    it 'other_pgpool_hostname settings attribute is not create' do
      expect(chef_run.node['pgpool_part']['pgconf'].include?('other_pgpool_hostname')).to be_falsey
    end
    it 'other_pgpool_port settings attribute is not create' do
      expect(chef_run.node['pgpool_part']['pgconf'].include?('other_pgpool_port')).to be_falsey
    end
    it 'other_wd_port settings attribute is not create' do
      expect(chef_run.node['pgpool_part']['pgconf'].include?('other_wd_port')).to be_falsey
    end
  end

  describe 'only one node of ap role other than its own node' do
    before do
      chef_run.node.set['cloudconductor']['servers'] = {
        'db1' => { 'roles' => 'db', 'private_ip' => '127.0.0.1' },
        'ap1' => { 'roles' => 'ap', 'private_ip' => '127.0.0.101' },
        'ap2' => { 'roles' => 'ap', 'private_ip' => '127.0.0.102' }
      }
      chef_run.converge(described_recipe)
    end

    it 'other_pgpool_hostname settings is one made and value is not own private_ip of ap role node' do
      expect(chef_run.node['pgpool_part']['pgconf']['other_pgpool_hostname0']).to eq('127.0.0.102')
    end

    it 'other_pgpool_port settings is one made and  value is equal port value' do
      expect(chef_run.node['pgpool_part']['pgconf']['other_pgpool_port0']).to eq(chef_run.node['pgpool_part']['pgconf']['port'])
    end

    it 'other_wd_port settings is one made and value is equal wd_port value' do
      expect(chef_run.node['pgpool_part']['pgconf']['other_wd_port0']).to eq(chef_run.node['pgpool_part']['pgconf']['wd_port'])
    end

    it 'heartbeat_destination settings is one made and value is not own private_ip of ap role node' do
      expect(chef_run.node['pgpool_part']['pgconf']['heartbeat_destination0']).to eq('127.0.0.102')
    end

    it 'heartbeat_destination_port settings is one made and value is wd_heartbeat_port value' do
      expect(chef_run.node['pgpool_part']['pgconf']['heartbeat_destination_port0'])
        .to eq(chef_run.node['pgpool_part']['pgconf']['wd_heartbeat_port'])
    end
    it 'each settings is write to pgpool.conf' do
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf")
        .with_content(/#{"other_pgpool_hostname0".ljust(25)} = '127.0.0.102'/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf").with_content(/#{"other_pgpool_port0".ljust(25)} = 9999/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf").with_content(/#{"other_wd_port0".ljust(25)} = 9000/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf")
        .with_content(/#{"heartbeat_destination0".ljust(25)} = '127.0.0.102'/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf")
        .with_content(/#{"heartbeat_destination_port0".ljust(25)} = 9694/)
    end
  end
  describe 'multiple node of ap role other than its own node' do
    before do
      chef_run.node.set['cloudconductor']['servers'] = {
        'db1' => { 'roles' => 'db', 'private_ip' => '127.0.0.1' },
        'ap1' => { 'roles' => 'ap', 'private_ip' => '127.0.0.101' },
        'ap2' => { 'roles' => 'ap', 'private_ip' => '127.0.0.102' },
        'ap3' => { 'roles' => 'ap', 'private_ip' => '127.0.0.103' }
      }
      chef_run.converge(described_recipe)
    end

    it 'other_pgpool_hostname settings is made the number of other ap nodes and value is private_ip of thatnode' do
      expect(chef_run.node['pgpool_part']['pgconf']['other_pgpool_hostname0']).to eq('127.0.0.102')
      expect(chef_run.node['pgpool_part']['pgconf']['other_pgpool_hostname1']).to eq('127.0.0.103')
    end

    it 'other_pgpool_port settings is made the number of other ap nodes and value is equal port value' do
      expect(chef_run.node['pgpool_part']['pgconf']['other_pgpool_port0']).to eq(chef_run.node['pgpool_part']['pgconf']['port'])
      expect(chef_run.node['pgpool_part']['pgconf']['other_pgpool_port1']).to eq(chef_run.node['pgpool_part']['pgconf']['port'])
    end

    it 'other_wd_port settings is made the number of other ap nodes and value is equal wd_port value' do
      expect(chef_run.node['pgpool_part']['pgconf']['other_wd_port0']).to eq(chef_run.node['pgpool_part']['pgconf']['wd_port'])
      expect(chef_run.node['pgpool_part']['pgconf']['other_wd_port1']).to eq(chef_run.node['pgpool_part']['pgconf']['wd_port'])
    end

    it 'heartbeat_destination settings is made the number of other ap nodes and value is private_ip of that node' do
      expect(chef_run.node['pgpool_part']['pgconf']['heartbeat_destination0']).to eq('127.0.0.102')
      expect(chef_run.node['pgpool_part']['pgconf']['heartbeat_destination1']).to eq('127.0.0.103')
    end

    it 'heartbeat_destination_port settings is made the number of other ap nodes and value is wd_heartbeat_port value' do
      expect(chef_run.node['pgpool_part']['pgconf']['heartbeat_destination_port0'])
        .to eq(chef_run.node['pgpool_part']['pgconf']['wd_heartbeat_port'])
      expect(chef_run.node['pgpool_part']['pgconf']['heartbeat_destination_port1'])
        .to eq(chef_run.node['pgpool_part']['pgconf']['wd_heartbeat_port'])
    end
    it 'each settings is write to pgpool.conf' do
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf")
        .with_content(/#{"other_pgpool_hostname0".ljust(25)} = '127.0.0.102'/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf").with_content(/#{"other_pgpool_port0".ljust(25)} = 9999/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf").with_content(/#{"other_wd_port0".ljust(25)} = 9000/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf")
        .with_content(/#{"heartbeat_destination0".ljust(25)} = '127.0.0.102'/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf")
        .with_content(/#{"heartbeat_destination_port0".ljust(25)} = 9694/)

      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf")
        .with_content(/#{"other_pgpool_hostname1".ljust(25)} = '127.0.0.103'/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf").with_content(/#{"other_pgpool_port1".ljust(25)} = 9999/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf").with_content(/#{"other_wd_port1".ljust(25)} = 9000/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf")
        .with_content(/#{"heartbeat_destination1".ljust(25)} = '127.0.0.103'/)
      expect(chef_run).to render_file("#{pgpool_dir}/pgpool.conf")
        .with_content(/#{"heartbeat_destination_port1".ljust(25)} = 9694/)
    end
  end
end
