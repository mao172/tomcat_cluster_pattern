default['postgresql']['enable_pgdg_yum'] = true
default['postgresql']['version'] = '9.4'
default['postgresql']['client']['packages'] = ["postgresql#{node['postgresql']['version'].split('.').join}-devel"]
default['postgresql']['server']['packages'] = ["postgresql#{node['postgresql']['version'].split('.').join}-server"]
default['postgresql']['contrib']['packages'] = ["postgresql#{node['postgresql']['version'].split('.').join}-contrib"]
default['postgresql']['dir'] = "/var/lib/pgsql/#{node['postgresql']['version']}/data"
default['postgresql']['server']['service_name'] = "postgresql-#{node['postgresql']['version']}"
default['postgresql']['password']['postgres'] = 'todo_replace_random_password'
default['postgresql']['config']['listen_addresses'] = '*'
default['postgresql']['config']['data_directory'] = node['postgresql']['dir']
default['postgresql']['config']['wal_level'] = 'hot_standby'
default['postgresql']['config']['max_wal_senders'] = '3'
default['postgresql']['config']['wal_keep_segments'] = '32'
default['postgresql']['config']['hot_standby'] = 'on'
default['postgresql']['config']['max_replication_slots'] = '1'
default['postgresql']['config']['synchronous_commit'] = 'off'
default['postgresql']['config']['synchronous_standby_names'] = '*'

default['postgresql_part']['home_dir'] = '/var/lib/pgsql'
default['postgresql_part']['replication']['user'] = 'replication'
default['postgresql_part']['replication']['password'] = 'todo_replace_random_password'
default['postgresql_part']['replication']['replication_slot'] = 'replication_slot'

default['postgresql_part']['recovery']['standby_mode'] = 'on'
default['postgresql_part']['recovery']['primary_slot_name'] = node['postgresql_part']['replication']['replication_slot']

default['postgresql_part']['application']['database'] = 'application'
default['postgresql_part']['application']['user'] = 'application'

default['postgresql_part']['pgpool-II']['use'] = true
default['postgresql_part']['pgpool-II']['source_archive_url'] = 'http://www.pgpool.net/download.php?f=pgpool-II-3.4.0.tar.gz'

default['postgresql_part']['event_handlers_dir'] = '/opt/consul/event_handlers'

# To merge because does not contain a "pgdg-repo" of postgresql 9.4 to postgresql cookbook now.
# if contains a "pgdg-repo" to postgresql cookbook to use it
unless node['postgresql']['pgdg']['repo_rpm_url'].include?('9.4')
  normal['postgresql']['pgdg']['repo_rpm_url'] = {
    '9.4' => {
      'centos' => {
        '6' => {
          'i386' => 'http://yum.postgresql.org/9.4/redhat/rhel-6-i386/pgdg-centos94-9.4-1.noarch.rpm',
          'x86_64' => 'http://yum.postgresql.org/9.4/redhat/rhel-6-x86_64/pgdg-centos94-9.4-1.noarch.rpm'
        }
      }
    }
  }
end
