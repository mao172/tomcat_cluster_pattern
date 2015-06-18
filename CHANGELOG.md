CHANGELOG
=========

## version 1.0.2 (2015/06/18)

  - Support to pre/post deploy script.
  - Add parameter to build resource in the correct order.
  - Pause replication from slave until master DB reload pg_hba.conf.

## version 1.0.1 (2015/04/16)

  - Fix restore script in backup_restore.yml to sync restore process among db master, slave, and application servers correctly.

## version 1.0.0 (2015/03/27)

  - First release of tomcat cluster pattern that build redundant three-tier system with haproxy, tomcat and postgresql.
