name 'tomcat_part'
version          '0.0.1'
description      'Installs/Configures Apache Tomcat and deploys applications'
license          'Apache v2.0'
maintainer       'TIS Inc.'
maintainer_email 'ccndctr@gmail.com'

supports 'centos', '= 6.5'

depends 'cloudconductor'
depends 'yum'
depends 'tomcat'
depends 'postgresql'
depends 'database'
