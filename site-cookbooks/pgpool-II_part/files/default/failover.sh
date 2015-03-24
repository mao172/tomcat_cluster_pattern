#!/bin/bash -x

NEW_MASTER_NODE=`consul members | grep ${1} | awk '{print $1}'`

consul event -name="failover" -node="$NEW_MASTER_NODE"

