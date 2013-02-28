#!/opt/chef/embedded/bin/ruby

require 'chef/environment'
require 'chef/data_bag'
require 'chef/data_bag_item'
require 'chef/json_compat'
require 'chef'

Chef::Config.from_file("/var/lib/jenkins/tools/ci-knife.rb")

environment_name = ARGV[0]
app_name = ARGV[1]
env = Chef::Environment.load_or_create(environment_name)

begin
  desired_release = env.override_attributes["apps"][app_name]['desired']
rescue
  puts "Cannot find a desired release for #{app_name}"
end

release = Chef::DataBagItem.load("repo_#{app_name}", desired_release)

print "GERRIT_PROJECT='#{release['gerrit_project']}' GERRIT_BRANCH='#{release['gerrit_branch']}' GERRIT_REFSPEC=#{release['gerrit_refspec']}"
