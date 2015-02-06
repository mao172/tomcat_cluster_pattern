default['pgpool_part']['repository']['baseurl'] = 'http://www.pgpool.net/yum/rpms/3.4/redhat/rhel-6-x86_64/'
default['pgpool_part']['repository']['gpgkey'] = 'http://www.pgpool.net/yum/RPM-GPG-KEY-PGPOOL2'
default['pgpool_part']['package_name'] = 'pgpool-II-pg94'
default['pgpool_part']['user'] = 'postgres'
default['pgpool_part']['group'] = 'postgres'
default['pgpool_part']['service'] = 'pgpool'
default['pgpool_part']['config']['dir'] = '/etc/pgpool-II'

default['pgpool_part']['pgconf']['logdir'] = '/var/log/pgpool'

default['pgpool_part']['pg_hba']['auth'] = [
  { type: 'local', db: 'all', user: 'all', addr: nil, method: 'trust' },
  { type: 'host', db: 'all', user: 'all', addr: '127.0.0.1/32', method: 'trust' },
  { type: 'host', db: 'all', user: 'all', addr: '::1/128', method: 'trust' }
]
