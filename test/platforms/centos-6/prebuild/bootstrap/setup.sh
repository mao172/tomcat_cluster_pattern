#!/bin/bash -x

cd /opt/cloudconductor
git checkout develop

cd /opt/cloudconductor/etc

echo 'group :test do' >> Berksfile
echo '  cookbook "consul", git: "https://github.com/johnbellone/consul-cookbook.git"' >> Berksfile
echo 'end' >> Berksfile
rm Berksfile.lock

berks vendor /opt/cloudconductor/tmp/cookbooks

cp /opt/cloudconductor/tmp/cookbooks/consul/templates/default/consul-init.erb /opt/cloudconductor/tmp/cookbooks/bootstrap/templates/default/

jq '. + {consul: {service_mode: "bootstrap"}}' /opt/cloudconductor/etc/node_setup.json >> node_setup_2.json

cd /opt/cloudconductor

source ./config

export PATTERN_NAME
export PATTERN_URL
export PATTERN_REVISION
export ROLE
export CONSUL_SECRET_KEY

chef-solo -j ./etc/node_setup_2.json -c ./etc/solo.rb
