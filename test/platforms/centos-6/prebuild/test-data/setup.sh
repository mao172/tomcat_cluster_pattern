#!/bin/sh

service consul start
sleep 5

script_dir=`dirname $0`

ROLE=$1

func_role_db() {
  case "$1" in
    "primary" ) $script_dir/servers.sh set $ROLE $1 ;;
    "standby" ) $script_dir/servers.sh ;;
  esac
}

case "${ROLE}" in
  "lb" ) ;;
  "web" ) ;;
  "ap" ) ;;
  "db" ) func_role_db ${2} ;;
esac
