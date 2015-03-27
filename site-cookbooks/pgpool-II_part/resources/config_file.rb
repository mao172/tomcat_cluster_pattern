#
# Cookbook Name:: pgpool-II_part
# Resource:: config_file
#

actions :create
default_action :create

attribute :name, kind_of: String, name_attribute: true

include Chef::Mixin::Securable
