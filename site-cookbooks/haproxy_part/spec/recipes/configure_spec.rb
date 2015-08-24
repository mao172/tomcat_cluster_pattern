#
# Cookbook Name:: haproxy_part
# Recipe:: configure_spec
#
#

require_relative '../spec_helper'
require_relative '../../../cloudconductor/libraries/consul_helper_kv'

RSpec.configure do |config|
  config.extend Chef::Mixin::DeepMerge
end

describe 'haproxy_part::configure' do
  let(:chef_run) { ChefSpec::SoloRunner.new(step_into: %w(haproxy haproxy_part_pem_file)) }

  web01_server_nm = 'web01'
  web02_server_nm = 'web02'

  web01_private_ip = '172.0.0.10'
  web02_private_ip = '172.0.0.11'

  pem_file_path = '/opt/haproxy/server.pem'
  pem_dir_path = '/opt/haproxy/ssl'

  def create_haproxy(name)
    ChefSpec::Matchers::ResourceMatcher.new(:haproxy, :create, name)
  end

  before do
    chef_run.node.set['cloudconductor']['servers'] = {
      web01_server_nm => {
        roles: 'web',
        private_ip: web01_private_ip
      },
      web02_server_nm => {
        roles: 'web',
        private_ip: web02_private_ip
      }
    }

    chef_run.node.set['cloudconductor']['applications'] = {
      app_name: {}
    }

    chef_run.node.set[:haproxy][:install_method] = 'source'

    chef_run.node.set['haproxy']['enable_stats_socket'] = false
    chef_run.node.set['haproxy']['enable_admin'] = false

    chef_run.node.set['haproxy']['enable_default_http'] = false
    chef_run.node.set['haproxy']['enable_ssl'] = false
    chef_run.node.set[:haproxy_part][:enable_ssl_proxy] = false
    chef_run.node.set[:haproxy_part][:enable_sticky_session] = false

    chef_run.node.set[:haproxy_part][:ssl_pem_dir] = pem_dir_path
    chef_run.node.set[:haproxy_part][:ssl_pem_file] = pem_file_path

    chef_run.node.set[:haproxy_part][:pem_file][:protocol] = 'consul'

    allow(CloudConductor::ConsulClient::KeyValueStore)
      .to receive(:get).with('ssl_pem').and_return('simple result text')
    allow(CloudConductor::ConsulClient::KeyValueStore).to receive(:keys).and_return('')

    chef_run.converge(described_recipe)
  end

  describe 'haproxy conf' do
    describe 'global parameter' do
      path = '/admin/stats'
      user = 'hapxyusr'
      group = 'hapxygp'

      before do
        chef_run.node.set['haproxy']['stats_socket_path'] = path
        chef_run.node.set['haproxy']['stats_socket_user'] = user
        chef_run.node.set['haproxy']['stats_socket_group'] = group

        chef_run.node.set[:haproxy][:config]['listen admin'] = nil

        chef_run.converge(described_recipe)
      end

      it 'stats socket' do
        chef_run.node.set['haproxy']['enable_stats_socket'] = true
        chef_run.converge(described_recipe)

        expect(chef_run.node[:haproxy][:config][:global]['stats socket']).to eq("#{path} user #{user} group #{group}")
      end

      it 'exclude stats socket' do
        chef_run.node.set['haproxy']['enable_stats_socket'] = false
        chef_run.converge(described_recipe)

        expect(chef_run.node[:haproxy][:config][:global]['stats socket']).to equal nil
      end
    end

    it 'listen admin' do
      chef_run.node.set['haproxy']['enable_admin'] = true
      chef_run.converge(described_recipe)

      expect(chef_run.node[:haproxy][:config]['listen admin'][:mode]).to equal :http
    end

    it 'exclude listen admin' do
      chef_run.node.set['haproxy']['enable_admin'] = false
      chef_run.converge(described_recipe)

      expect(chef_run.node[:haproxy][:config]['listen admin']).to equal nil
    end
  end

  describe 'for SSL pem file' do
    before do
      chef_run.node.set['haproxy']['enable_ssl'] = false
      chef_run.node.set[:haproxy_part][:enable_ssl_proxy] = true

      chef_run.node.set[:haproxy][:source][:prefix] = '/opt'

      chef_run.converge(described_recipe)
    end

    it 'create a directory for pem file' do
      prefix = chef_run.node[:haproxy][:install_method] == 'source' ? '/opt' : nil
      expect(chef_run).to create_directory("#{prefix}#{pem_dir_path}")
    end

    it 'create pem file' do
      prefix = chef_run.node[:haproxy][:install_method] == 'source' ? '/opt' : nil
      expect(chef_run).to create_file("#{prefix}#{pem_file_path}")
    end
  end

  describe 'create haproxy.cfg' do
    config = nil
    config_pool = {}

    before do
      chef_run.node.set[:haproxy][:source][:prefix] = '/opt'
      chef_run.converge(described_recipe)
      config = chef_run.node[:haproxy][:config]
    end

    def make_hash(attr)
      new_hash = {}
      attr.each do |k, v|
        if v.is_a?(Hash)
          new_hash[k] = make_hash(v)
        else
          new_hash[k] = v
        end
      end
      new_hash
    end

    include Chef::Mixin::DeepMerge

    it 'without all' do
      config_pool = merge(make_hash(config), config_pool)

      expect(chef_run).to create_haproxy('myhaproxy').with(
        config: config_pool
      )

      prefix = chef_run.node[:haproxy][:install_method] == 'source' ? '/opt' : nil
      expect(chef_run).to create_template("#{prefix}/etc/haproxy/haproxy.cfg")
    end

    describe 'with default html' do
      before do
        chef_run.node.set['haproxy']['enable_default_http'] = true
        chef_run.node.set[:haproxy_part][:enable_sticky_session] = false
        chef_run.converge(described_recipe)

        config_pool = {}
        config_pool['frontend http'] = {
          maxconn: 2000,
          bind: '0.0.0.0:80',
          default_backend: 'servers-http'
        }
      end

      it 'disable sticky session' do
        params = {
          server: [
            "#{web01_server_nm} #{web01_private_ip}:80 weight 1 maxconn 100 check",
            "#{web02_server_nm} #{web02_private_ip}:80 weight 1 maxconn 100 check"
          ],
          option: []
        }

        config_pool['backend servers-http'] = merge(make_hash(chef_run.node[:haproxy_part][:backend_params]), params)

        config_pool = merge(make_hash(config), config_pool)
        expect(chef_run).to create_haproxy('myhaproxy').with(
          config: config_pool
        )
      end

      it 'sticky session on app-session cookie' do
        chef_run.node.set[:haproxy_part][:enable_sticky_session] = true
        chef_run.node.set[:haproxy_part][:sticky_session_method] = :appsession
        chef_run.converge(described_recipe)

        params = {
          server: [
            "#{web01_server_nm} #{web01_private_ip}:80 weight 1 maxconn 100 check",
            "#{web02_server_nm} #{web02_private_ip}:80 weight 1 maxconn 100 check"
          ],
          option: [],
          appsession: 'JSESSIONID len 32 timeout 3h request-learn'
        }

        config_pool['backend servers-http'] = merge(make_hash(chef_run.node[:haproxy_part][:backend_params]), params)

        config_pool = merge(make_hash(config), config_pool)
        expect(chef_run).to create_haproxy('myhaproxy').with(
          config: config_pool
        )
      end

      it 'sticky session on cookie' do
        chef_run.node.set[:haproxy_part][:enable_sticky_session] = true
        chef_run.node.set[:haproxy_part][:sticky_session_method] = :cookie
        chef_run.converge(described_recipe)

        params = {
          server: [
            "#{web01_server_nm} #{web01_private_ip}:80 weight 1 maxconn 100 check cookie #{web01_server_nm}",
            "#{web02_server_nm} #{web02_private_ip}:80 weight 1 maxconn 100 check cookie #{web02_server_nm}"
          ],
          option: [],
          cookie: 'SERVERID insert indirect nocache'
        }

        config_pool['backend servers-http'] = merge(make_hash(chef_run.node[:haproxy_part][:backend_params]), params)

        config_pool = merge(make_hash(config), config_pool)
        expect(chef_run).to create_haproxy('myhaproxy').with(
          config: config_pool
        )
      end
    end

    describe 'with https' do
      before do
        chef_run.node.set['haproxy']['enable_ssl'] = true
        chef_run.node.set[:haproxy][:ssl_member_port] = 443
        chef_run.node.set[:haproxy_part][:enable_sticky_session] = false
        chef_run.converge(described_recipe)

        config_pool = {}

        config_pool['frontend https'] = {
          maxconn: 2000,
          bind: '0.0.0.0:443',
          default_backend: 'servers-https'
        }
      end

      it 'disable sticky_session' do
        params = {
          mode: :tcp,
          server: [
            "#{web01_server_nm} #{web01_private_ip}:443 weight 1 maxconn 100 check",
            "#{web02_server_nm} #{web02_private_ip}:443 weight 1 maxconn 100 check"
          ],
          option: ['ssl-hello-chk']
        }

        config_pool['backend servers-https'] = merge(make_hash(chef_run.node[:haproxy_part][:backend_params]), params)

        config_pool = merge(make_hash(config), config_pool)
        expect(chef_run).to create_haproxy('myhaproxy').with(
          config: config_pool
        )
      end
      it 'sticky session on app-session cookie' do
        chef_run.node.set[:haproxy_part][:enable_sticky_session] = true
        chef_run.node.set[:haproxy_part][:sticky_session_method] = :appsession
        chef_run.converge(described_recipe)

        params = {
          mode: :tcp,
          server: [
            "#{web01_server_nm} #{web01_private_ip}:443 weight 1 maxconn 100 check",
            "#{web02_server_nm} #{web02_private_ip}:443 weight 1 maxconn 100 check"
          ],
          option: ['ssl-hello-chk'],
          appsession: 'JSESSIONID len 32 timeout 3h request-learn'
        }

        config_pool['backend servers-https'] = merge(make_hash(chef_run.node[:haproxy_part][:backend_params]), params)

        config_pool = merge(make_hash(config), config_pool)
        expect(chef_run).to create_haproxy('myhaproxy').with(
          config: config_pool
        )
      end
      it 'sticky session on cookie' do
        chef_run.node.set[:haproxy_part][:enable_sticky_session] = true
        chef_run.node.set[:haproxy_part][:sticky_session_method] = :cookie
        chef_run.converge(described_recipe)

        params = {
          mode: :tcp,
          server: [
            "#{web01_server_nm} #{web01_private_ip}:443 weight 1 maxconn 100 check cookie #{web01_server_nm}",
            "#{web02_server_nm} #{web02_private_ip}:443 weight 1 maxconn 100 check cookie #{web02_server_nm}"
          ],
          option: ['ssl-hello-chk'],
          cookie: 'SERVERID insert indirect nocache'
        }

        config_pool['backend servers-https'] = merge(make_hash(chef_run.node[:haproxy_part][:backend_params]), params)

        config_pool = merge(make_hash(config), config_pool)
        expect(chef_run).to create_haproxy('myhaproxy').with(
          config: config_pool
        )
      end
    end

    describe 'with ssl proxy' do
      before do
        # method = chef_run.node[:haproxy][:install_method]
        # prefix = "#{chef_run.node[:haproxy][method][:prefix]}"

        chef_run.node.set['haproxy_part']['enable_ssl_proxy'] = true
        chef_run.node.set[:haproxy_part][:ssl_pem_dir] = pem_dir_path
        chef_run.node.set[:haproxy_part][:ssl_pem_file] = pem_file_path
        chef_run.node.set[:haproxy_part][:pem_file][:protocol] = 'node'
        chef_run.node.set[:haproxy_part][:ssl_pem] = '<!-- PEM FILE -->'

        chef_run.converge(described_recipe)
      end

      it 'pem file' do
        method = chef_run.node[:haproxy][:install_method]
        prefix = "#{chef_run.node[:haproxy][method][:prefix]}"

        expect(chef_run).to create_file("#{prefix}#{pem_file_path}").with(
          content: '<!-- PEM FILE -->',
          owner: 'root',
          group: 'root',
          mode: '0644'
        )
      end

      it 'pem file form remote' do
        chef_run.node.set[:haproxy_part][:pem_file][:protocol] = 'remote'
        chef_run.node.set[:haproxy_part][:pem_file][:remote][:url] = 'https://s3-us-west-1.amazonaws.com/okamoto-cloudconductor/%EF%BD%83ertificate/server.pem'
        chef_run.converge(described_recipe)

        expect(chef_run).to create_remote_file('ssl_pem')
      end

      it 'configure do' do
        method = chef_run.node[:haproxy][:install_method]
        prefix = "#{chef_run.node[:haproxy][method][:prefix]}"

        config_pool = {}

        params = {
          server: [
            "#{web01_server_nm} #{web01_private_ip}:80 weight 1 maxconn 100 check",
            "#{web02_server_nm} #{web02_private_ip}:80 weight 1 maxconn 100 check"
          ],
          option: []
        }

        config_pool['backend servers-http'] = merge(make_hash(chef_run.node[:haproxy_part][:backend_params]), params)

        config_pool['frontend ssl-proxy'] = {
          maxconn: 2000,
          bind: "0.0.0.0:443 ssl crt #{prefix}#{pem_file_path}",
          'mode' => :http,
          default_backend: 'servers-http'
        }

        config_pool = merge(make_hash(config), config_pool)

        expect(chef_run).to create_haproxy('myhaproxy').with(
          config: config_pool
        )
      end
    end
  end
end
