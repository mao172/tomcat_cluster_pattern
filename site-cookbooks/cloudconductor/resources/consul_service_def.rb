#
# Cookbook Name:: cloudconductor
# Resource:: consul_service_def
#
#

require 'json'

actions :create, :delete
default_action :create

attribute :name, name_attribute: true, required: true, kind_of: String
attribute :id, kind_of: String
attribute :port, kind_of: Integer
attribute :tags, kind_of: Array, default: nil
attribute :check, kind_of: Hash, default: nil, callbacks: {
  'Checks must be a hash containing either a `:ttl` key/value or a `:script` and `:interval` key/value' => ->(check) do
    Chef::Resource::CloudconductorConsulServiceDef.validate_check(check)
  end
}

def self.validate_check(check)
  unless check.is_a?(Hash)
    return false
  end
  if check.key?(:ttl) && (!check.key?(:interval) && !check.key?(:script))
    return true
  end
  if check.key?(:interval) && check.key?(:script)
    return true
  end
  false
end

def user
  node['cloudconductor']['consul']['service_user']
end

def group
  node['cloudconductor']['consul']['service_group']
end

def path
  ::File.join(node[:cloudconductor][:consul][:config_dir], "#{id || name}.json")
end

def to_json
  JSON.pretty_generate(to_hash)
end

def to_hash
  hash = {
    service: {
      name: name
    }
  }
  hash[:service][:id] = id unless id.nil?
  hash[:service][:port] = port unless port.nil?
  hash[:service][:tags] = tags unless tags.nil?
  hash[:service][:check] = check unless check.nil?
  hash
end
