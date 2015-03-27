#!/bin/sh

if [ "$1" == "" ] ; then
  echo "new master node has not been specified in the argument !!"
  exit -1
fi

NEW_MASTER_NODE=`consul members | grep ${1} | awk '{print $1}'`

echo "NEW_MASTER_NODE=${NEW_MASTER_NODE}"

if [ "$NEW_MASTER_NODE" == ""  ] ; then
  echo "new master node name is not found !!"
  exit -1
fi

consul event -name="failover" -node="$NEW_MASTER_NODE"
