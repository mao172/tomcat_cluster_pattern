name             'haproxy_part'
maintainer       'TIS Inc.'
maintainer_email 'ccndctr@gmail.com'
license          'Apache v2.0'
description      'Installs/Configures haproxy'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

supports 'centos', '= 6.5'

depends 'cloudconductor'
depends 'haproxy'
depends 'rsyslog'
