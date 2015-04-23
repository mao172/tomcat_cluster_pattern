#!/bin/bash -x
LANG=en_US.UTF-8

service consul start
sleep 5

export PATH=${PATH}:/opt/chef/embedded/bin

cd /opt/cloudconductor
bash -x ./bin/configure.sh >& ./logs/configure.log
