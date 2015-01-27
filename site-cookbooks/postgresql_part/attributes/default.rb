default['postgresql']['enable_pgdg_yum'] = true
default['postgresql']['version'] = '9.3'
default['postgresql']['client']['packages'] = ["postgresql#{node['postgresql']['version'].split('.').join}-devel"]
default['postgresql']['server']['packages'] = ["postgresql#{node['postgresql']['version'].split('.').join}-server"]
default['postgresql']['contrib']['packages'] = ["postgresql#{node['postgresql']['version'].split('.').join}-contrib"]
default['postgresql']['dir'] = "/var/lib/pgsql/#{node['postgresql']['version']}/data"
default['postgresql']['server']['service_name'] = "postgresql-#{node['postgresql']['version']}"
default['postgresql']['password']['postgres'] = 'todo_replace_random_password'
default['postgresql']['config']['listen_addresses'] = '*'
default['postgresql']['config']['data_directory'] = node['postgresql']['dir']

default['postgresql_part']['application']['database'] = 'application'
default['postgresql_part']['application']['user'] = 'application'
default['postgresql_part']['application']['password'] = 'todo_replace_random_password'

# To merge because does not contain a "pgdg-repo" of postgresql 9.4 to postgresql cookbook now.
# if contains a "pgdg-repo" to postgresql cookbook to use it
unless node['postgresql']['pgdg']['repo_rpm_url'].include?("9.4")
  normal['postgresql']['pgdg']['repo_rpm_url'] = {
    "9.4" => {
      "centos" => {
        "6" => {
          "i386" => "http://yum.postgresql.org/9.4/redhat/rhel-6-i386/pgdg-centos94-9.4-1.noarch.rpm",
          "x86_64" => "http://yum.postgresql.org/9.4/redhat/rhel-6-x86_64/pgdg-centos94-9.4-1.noarch.rpm"
        }
      }
    }
  }
end
