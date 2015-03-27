actions :create
default_action :create

attribute :table_name,
          kind_of: String,
          name_attribute: true

##
attribute :session_db,
          kind_of: Hash

attribute :session_table,
          kind_of: Hash
