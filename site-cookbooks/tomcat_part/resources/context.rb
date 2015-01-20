actions :create
default_action :create

attribute :app_name,
          kind_of: String,
          name_attribute: true

##
attribute :session_replication,
          kind_of: String

attribute :use_jndi,
          kind_of: [TrueClass, FalseClass],
          equal_to: [true, false]

attribute :use_db,
          kind_of: [TrueClass, FalseClass],
          equal_to: [true, false]

##
attribute :datasource,
          kind_of: String
attribute :database,
          kind_of: Hash

##
attribute :session_db,
          kind_of: Hash
attribute :session_table,
          kind_of: Hash

attribute :sessionTableName,
          kind_of: String
