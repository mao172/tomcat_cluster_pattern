# tomcat_part attributes.
# for JDBCStore

# session replication mode
# value is 'none' or 'jdbcStore'. (or 'fileStore', 'inMemory'. These will be supported later. )
default['tomcat_part']['session_replication'] = 'jdbcStore'

# attributes of database for session-replication
default['tomcat_part']['session_db']['dataSourceName'] = 'jdbc/session_db'
default['tomcat_part']['session_db']['type'] = 'postgresql'
default['tomcat_part']['session_db']['name'] = 'session'
default['tomcat_part']['session_db']['user'] = 'tomcat'
default['tomcat_part']['session_db']['password'] = 'tomcat'
default['tomcat_part']['session_db']['host'] = 'localhost'
default['tomcat_part']['session_db']['port'] = 5432

# value is true when define jndi resources for session replication database.
default['tomcat_part']['use_jndi'] = true

# attributes for session store table
default['tomcat_part']['session_table']['name'] = 'tomcat_session'
default['tomcat_part']['session_table']['idCol'] = 'session_id'
default['tomcat_part']['session_table']['appCol'] = 'app_name'
default['tomcat_part']['session_table']['dataCol'] = 'session_data'
default['tomcat_part']['session_table']['lastAccessedCol'] = 'last_access'
default['tomcat_part']['session_table']['maxInactiveCol'] = 'max_inactive'
default['tomcat_part']['session_table']['validCol'] = 'valid_session'
