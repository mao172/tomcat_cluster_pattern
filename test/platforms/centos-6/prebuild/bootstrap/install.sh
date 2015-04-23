#!/bin/bash -x

git clone https://github.com/cloudconductor/cloudconductor_init.git /opt/cloudconductor
cd /opt/cloudconductor
git checkout develop
mkdir -p /opt/cloudconductor/logs
mkdir -p /opt/cloudconductor/tmp

git clone https://github.com/cloudconductor/cloud_conductor_utils.git /opt/cloudconductor/tmp/cloud_conductor_utils

touch ./dummy_iptables
cp ./dummy_iptables /etc/init.d/iptables

export PATH=${PATH}:/opt/chef/embedded/bin

cd /opt/cloudconductor/tmp/cloud_conductor_utils

/opt/chef/embedded/bin/rake build
/opt/chef/embedded/bin/gem install ./pkg/*.gem

curl -o /usr/bin/jq http://stedolan.github.io/jq/download/linux64/jq && chmod +x /usr/bin/jq
