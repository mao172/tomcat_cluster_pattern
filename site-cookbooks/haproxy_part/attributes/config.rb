#
# Cookbook Name:: haproxy_part
# Attribute:: config
#
## Base attributes used when generating configuration using default LWRP
#
#

# default[:haproxy][:config][:global][:log]['127.0.0.1'][:local0] = nil
# default[:haproxy][:config][:global][:log]['127.0.0.1'][:local1] = :notice
default[:haproxy][:config][:global][:log]['127.0.0.1'] = { 'local0' => 'info' }
default[:haproxy][:config][:global][:maxconn] = node[:haproxy][:global_max_connections]
default[:haproxy][:config][:global][:user] = node[:haproxy][:user]
default[:haproxy][:config][:global][:group] = node[:haproxy][:group]

default[:haproxy][:config][:global][:option] = node['haproxy']['global_options']

default[:haproxy][:config][:defaults][:log] = :global
default[:haproxy][:config][:defaults][:mode] = node['haproxy']['mode']
default[:haproxy][:config][:defaults][:retries] = 3
default[:haproxy][:config][:defaults][:timeout][:client] = node['haproxy']['defaults_timeouts']['client']
default[:haproxy][:config][:defaults][:timeout][:server] = node['haproxy']['defaults_timeouts']['server']
default[:haproxy][:config][:defaults][:timeout][:connect] = node['haproxy']['defaults_timeouts']['connect']
default[:haproxy][:config][:defaults][:option] = node['haproxy']['defaults_options']
default[:haproxy][:config][:defaults][:balance] = node['haproxy']['balance_algorithm']
