require_relative '../spec_helper'
require_relative '../../../cloudconductor/libraries/helper'
require_relative '../../../cloudconductor/libraries/consul_helper'
require_relative '../../../cloudconductor/libraries/consul_helper_kv'

describe 'apache_part::configure' do
  let(:chef_run) { ChefSpec::SoloRunner.new }

  server_name = 'cehfs'
  private_ip = '172.0.0.1'

  before do
    chef_run.node.set['cloudconductor']['servers'] = {
      server_name => {
        roles: 'ap',
        private_ip: private_ip
      }
    }
    allow(CloudConductor::ConsulClient::KeyValueStore).to receive(:keys).and_return('')

    chef_run.converge(described_recipe)
  end

  describe 'create template file' do
    sticky_session = true

    it 'used loadbalancer' do
      chef_run.node.set['apache_part']['sticky_session'] = sticky_session
      chef_run.converge(described_recipe)

      expect(chef_run.node['apache']['conf_dir']).to eq('/etc/httpd/conf')
      expect(chef_run).to create_template('/etc/httpd/conf/workers.properties').with(
        source: 'workers.properties.erb',
        mode: '0664',
        variables: {
          worker_name: 'loadbalancer',
          tomcat_servers: [
            'name' => server_name,
            'host' => private_ip,
            'route' => private_ip,
            'weight' => 1
          ],
          sticky_session: sticky_session
        }
      )
    end

    it 'unused loadbalancer' do
      ip_addr = chef_run.node['ipaddress']
      chef_run.node.set['cloudconductor']['servers'][server_name]['private_ip'] = ip_addr
      chef_run.node.set['apache_part']['sticky_session'] = sticky_session
      chef_run.converge(described_recipe)

      expect(chef_run.node['apache']['conf_dir']).to eq('/etc/httpd/conf')
      expect(chef_run).to create_template('/etc/httpd/conf/workers.properties').with(
        source: 'workers.properties.erb',
        mode: '0664',
        variables: {
          worker_name: server_name,
          tomcat_servers: [
            'name' => server_name,
            'host' => ip_addr,
            'route' => ip_addr,
            'weight' => 1
          ],
          sticky_session: sticky_session
        }
      )
    end
  end

  it 'restart apaceh2 service' do
    service = chef_run.service('apache2')
    expect(service).to do_nothing
    expect(service.reload_command).to eq('/sbin/service httpd graceful')
    expect(chef_run.template('/etc/httpd/conf/workers.properties')).to notify('service[apache2]').to(:reload).delayed
  end
end
