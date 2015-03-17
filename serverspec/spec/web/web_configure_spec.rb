require 'spec_helper.rb'

# Check Service status

describe service('httpd') do
  it { should be_running }
end

# Cehck listen port
describe port(80) do
  it { should be_listening.with('tcp') }
end

# Check connect ap servers
describe command('hping3 -S localhost -p 8009 -c 5') do
  its(:stdout) { should match(/sport=8009 flags=SA/) }
end
