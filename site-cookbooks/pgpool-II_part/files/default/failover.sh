#!/bin/sh

virtual_addr_list() {
  if [ "${CONSUL_SECRET_KEY}" == "" ]; then
    CONSUL_SECRET_KEY=$(cat /etc/consul.d/default.json | jq -r .acl_master_token)
  fi

  CONSUL_SECRET_KEY_ENCODED=$(python -c "import urllib; print urllib.quote('${CONSUL_SECRET_KEY}')")

  keys=$(curl -s http://localhost:8500/v1/kv/cloudconductor/networks/?keys\&token=${CONSUL_SECRET_KEY_ENCODED} | jq -r .[])

  for key in ${keys[@]}
  do
    echo $key
    token=($(echo ${key} | tr -s '/' ' '))
    hostname=${token[2]}
    portname=${token[3]}
    json=$(curl -s http://localhost:8500/v1/kv/${key}?raw\&token=${CONSUL_SECRET_KEY_ENCODED})
    v_addr=$(echo ${json} | jq -r '.[][][][] | .virtual_address')
    echo ${hostname} ${portname} ${v_addr}
  done
}

if [ "$1" == "" ] ; then
  echo "new master node has not been specified in the argument !!"
  exit -1
fi

NEW_MASTER_NODE=`consul members | grep ${1} | awk '{print $1}'`

if [ "$NEW_MASTER_NODE" == ""  ] ; then
  NEW_MASTER_NODE=$(virtual_addr_list | grep ${1} | awk '{ print $1 }')
fi

echo "NEW_MASTER_NODE=${NEW_MASTER_NODE}"

if [ "$NEW_MASTER_NODE" == ""  ] ; then
  echo "new master node name is not found !!"
  exit -1
fi

consul event -name="failover" -node="$NEW_MASTER_NODE"
