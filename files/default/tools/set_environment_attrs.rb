#!/opt/chef/embedded/bin/ruby
#
# Takes fragments of environment data and slams them into a given environment 
#

require 'chef/environment'
require 'chef'

Chef::Config.from_file("/var/lib/jenkins/tools/ci-knife.rb")

def set_env_attrs(to, fragment_file)
  if File.exists?(fragment_file)
    fragment_data = Chef::JSONCompat.from_json(IO.read(fragment_file))
    fragment_data["default_attributes"].each do |k,v|
      to.default_attributes[k] = v
    end
    fragment_data["override_attributes"].each do |k,v|
      to.override_attributes[k] = v
    end
  end
end

environment_name = ARGV[0]
app_name = ARGV[2]
fragment_file = File.expand_path(File.join(ENV['WORKSPACE'], "environment_fragments", "#{environment_name}.json")) 

if ARGV[1] == "integration"
  patchset = Chef::Environment.load_or_create(environment_name).override_attributes["chef_repo"][environment_name]
  if app_name
    app_level = Chef::Environment.load_or_create(environment_name).override_attributes["apps"][app_name]
  end

  Chef::Environment.list.each do |env, uri|
    if env != environment_name && env =~ /^(dev-|integration)/
      to = Chef::Environment.load_or_create(env)
      set_env_attrs(to, fragment_file) 
      to.override_attributes["chef_repo"] ||= {}
      to.override_attributes["chef_repo"][environment_name] = patchset
      if app_name
        to.override_attributes["apps"] ||= {}
        to.override_attributes["apps"][app_name] = app_level
      end
      to.save
    end 
  end
else
  to = Chef::Environment.load_or_create(environment_name)
  set_env_attrs(to, fragment_file)
  to.override_attributes["chef_repo"] ||= {}
  to.override_attributes["chef_repo"][environment_name] = { "project" => ENV['GERRIT_PROJECT'],
                                                            "revision" => ENV['GERRIT_PATCHSET_REVISION'] }
  to.save
end

