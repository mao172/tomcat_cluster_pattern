#
# Spec:: web_configure_spec
#
#

require 'spec_helper.rb'

describe service('haproxy') do
  it { should be_running }
end

describe service('rsyslog') do
  it { should be_running }
end

describe port(80) do
  it { should be_listening.with('tcp') }
end

describe port(443) do
  it { should be_listening.with('tcp') }
end

describe 'connect web_servers' do
  web_servers = property[:servers].each_value.select do |server|
    server[:roles].include?('web')
  end

  web_servers.each do |server|
    describe command("hping3 -S #{server[:private_ip]} -p 80 -c 5") do
      its(:stdout) { should match(/sport=80 flags=SA/) }
    end
  end
end
