#
# Cookbook Name:: haproxy_part
# Resource:: pem_file
#
#

actions :create
default_action :create

##

attribute :file_name,
          kind_of: String,
          name_attribute: true
