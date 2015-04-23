#!/bin/bash -x

join_addr=${1}

local_addr=`LANG=C /sbin/ifconfig | grep 'inet addr' | grep -v 127.0.0.1 | awk '{print $2;}' | cut -d: -f2`

if [ "${join_addr}" != "${local_addr}" ] ; then
  jq ". + {bootstrap: false, start_join: [\"${join_addr}\"]}" /etc/consul.d/default.json >> /etc/consul.d/default2.json
  rm /etc/consul.d/default.json

  mv /etc/consul.d/default2.json /etc/consul.d/default.json
fi
