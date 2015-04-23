#!/bin/sh

source /opt/cloudconductor/config

hostname=`hostname`
key=cloudconductor/servers/

func_set() {
  roles=$1

  ip_addr=`hostname -i`

  json="{\"roles\":\"${roles}\",\"private_ip\":\"${ip_addr}\"}"

  echo "key=${key}${hostname}"
  echo ${json}

  curl -XPUT -d ${json} http://localhost:8500/v1/kv/${key}${hostname}?token=${CONSUL_SECRET_KEY_ENCODED}

  curl -s http://localhost:8500/v1/kv/${key}${hostname}?token=${CONSUL_SECRET_KEY_ENCODED} | jq '.[].Value | .' -r | base64 -d | jq '.'
}

func_remove() {

  if [ "${1}" != "" ] ; then
    hostname=${1}
  fi

  curl -XDELETE http://localhost:8500/v1/kv/${key}${hostname}?token=${CONSUL_SECRET_KEY_ENCODED}
}

func_list() {
  curl -s -XGET http://localhost:8500/v1/kv/cloudconductor/servers?keys\&token=${CONSUL_SECRET_KEY_ENCODED} | jq '.[]'
  curl -s -XGET http://localhost:8500/v1/kv/${key}?recurse\&token=${CONSUL_SECRET_KEY_ENCODED} | jq '.[].Value | .' -r | base64 -d | jq '.'
}

set_ruby_path() {
  if ! which ruby ; then
    if [ -d /opt/chef ] ; then
      export PATH=${PATH}:/opt/chef/embedded/bin
    fi

    if [ -d /opt/chefdk ] ; then
      export PATH=${PATH}:/opt/chefdk/embedded/bin
    fi
  fi
}

if [ "${CONSUL_SECRET_KEY}" != "" ] ; then
  set_ruby_path
  CONSUL_SECRET_KEY_ENCODED=`ruby -e "require 'cgi'; puts CGI::escape('${CONSUL_SECRET_KEY}')"`
fi

echo "CONSUL_SECRET_KEY_ENCODED=${CONSUL_SECRET_KEY_ENCODED}"

case $1 in
  set) func_set $2 ;;
  remove) func_remove $2 ;;
  list) func_list;;
esac
