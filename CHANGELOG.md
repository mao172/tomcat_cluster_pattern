CHANGELOG
=========

## version 1.1.0 (2015/09/30)

  - Support CloudConductor v1.1.
  - Remove the event_handler.sh, modified to control by the Metronome (task order control tool).Therefore, add the requirements(task.yml file etc.) to control from the Metronome.
  - Fix malformed json of service definitions for consul.
  - Remove cloud_conductor_util gem from the required gems.
  - Change to enable JMX access port for monitoring by Zabbix.
  - Add the requirements necessary for use in combination with vnet pattern.

## version 1.0.2 (2015/06/18)

  - Support to pre/post deploy script.
  - Add parameter to build resource in the correct order.
  - Pause replication from slave until master DB reload pg_hba.conf.

## version 1.0.1 (2015/04/16)

  - Fix restore script in backup_restore.yml to sync restore process among db master, slave, and application servers correctly.

## version 1.0.0 (2015/03/27)

  - First release of tomcat cluster pattern that build redundant three-tier system with haproxy, tomcat and postgresql.
