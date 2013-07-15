#!/opt/chef/embedded/bin/ruby
#
# Promote out of one org/environment to another org/environment
#

STDOUT.flush

require 'chef/environment'
require 'chef/knife'
require 'chef/knife/cookbook_download'
require 'chef/knife/cookbook_upload'
require 'chef'

Chef::Log.level = :info

module PromoteConfig
  class << self
    def load(from, to)
      @knife_rb = "/var/lib/jenkins/tools/ci-knife.rb"
      @from = from
      @to = to
      @identical = !!from[:server_url].match(to[:server_url])
      Chef::Log.info("Using #{from[:server_url]} and #{to[:server_url]} which are identical?: #{@identical}")
    end

    def use_from
      ENV['NODE_NAME'] = @from[:node_name]
      ENV['CLIENT_KEY'] = @from[:client_key]
      ENV['CHEF_SERVER_URL'] = @from[:server_url]
      Chef::Config.from_file(@knife_rb)
      Chef::Log.info("Using the from server: #{Chef::Config['chef_server_url']}")
    end

    def use_to
      ENV['NODE_NAME'] = @from[:node_name]
      ENV['CLIENT_KEY'] = @from[:client_key]
      ENV['CHEF_SERVER_URL'] = @from[:server_url]
      Chef::Config.from_file(@knife_rb)
      Chef::Log.info("Using the to server: #{Chef::Config['chef_server_url']}")
    end

    def same_config?
      @identical 
    end
  end
end

def download_cookbook(cookbook, version)
  Chef::Log.info("Downloading #{cookbook} version #{version}")
  PromoteConfig.use_from
  cookbook_file_path = File.expand_path(File.join(Chef::Config[:cookbook_path][0], cookbook))
  Chef::ShellOut.new("mkdir -p #{cookbook_file_path}").run_command.error!
  download = Chef::Knife::CookbookDownload.new
  download.config['download_directory'] = cookbook_file_path
  download.config['force'] = true
  download.name_args = [ cookbook, version ]
  download.run
end

def upload_cookbook(cookbook)
  Chef::Log.info("Uploading #{cookbook}")
  PromoteConfig.use_to
  cookbook_file_path = File.expand_path(File.join(Chef::Config[:cookbook_path][0], cookbook))
  upload = Chef::Knife::CookbookUpload.new
  upload.config['cookbook_path'] = cookbook_path
  upload.config['force'] = true
  upload.name_args = [ cookbook ]
  upload.run
end

def sanitize_cookbook_list(cookbook_list)
  new_cookbooks = {}
  cookbook_list.each do |cookbook_name, cookbook_data|
    new_cookbooks[cookbook_name] ||= {}
    cookbook_data["versions"].each do |vobj|
      new_cookbooks[cookbook_name][vobj["version"]] = true
    end
  end
  new_cookbooks
end

from = {
  :server_url => ARGV[0],
  :node_name => ARGV[1],
  :client_key => ARGV[2],
  :environment_name => ARGV[3]
}

to = {
  :server_url => ARGV[4],
  :node_name => ARGV[5],
  :client_key => ARGV[6],
  :environment_name => ARGV[7]
}

# promote from_config environment to_config environment
PromoteConfig.load(from, to)

# Load the environment you want to promote from
PromoteConfig.use_from
from_environment = Chef::Environment.load_or_create(from[:environment_name])

# Load the environment you want to promote to
PromoteConfig.use_to
begin
  to_environment = Chef::Environment.load_or_create(to[:environment_name])
rescue Net::HTTPServerException => e
  raise e unless e.response.code == "404"
  to_environment = Chef::Environment.new
  to_environment.name to_environment_name
end
to_environment.cookbook_versions from_environment.cookbook_versions
to_environment.override_attributes["apps"] = from_environment.override_attributes["apps"]
to_environment.override_attributes["chef_repo"] = from_environment.override_attributes["chef_repo"]

Chef::Log.info("Promoting environment from #{from[:environment_name]} to #{to[:environment_name]}")
# From here on out, we have broken the environment unless all the cookbook
# constraints get satisfied Heads way the hell up, kids.
to_environment.save

unless PromoteConfig.same_config?
  ## Get the data bags from the environment we are promoting from
  ## Put them in place in the environment we are promoting to
  PromoteConfig.use_from
  Chef::Log.info("Syncing data bags")
  Chef::DataBag.list.each do |data_bag_name, data_bag_uri|
    Chef::Log.info("Retrieving list of data bags..")
    # Get the list of data bag items
    PromoteConfig.use_from
    data_bag_from = Chef::DataBag.load(data_bag_name)

    Chef::Log.info("Creating remote data bag")
    # Create the data bag on the other end
    PromoteConfig.use_to
    # Accept that the data bag might already exist, so the save returns a 409
    begin
      data_bag_to = Chef::DataBag.new
      data_bag_to.name(data_bag_name)
      data_bag_to.save
    rescue Net::HTTPServerException => e
      Chef::Log.info("Data bag already existed")
      raise e unless e.response.code == "409"
    end

    data_bag_from.each do |data_bag_item_id, data_bag_item_uri|
      PromoteConfig.use_from
      Chef::Log.info("Syncing data bag #{data_bag_name} item #{data_bag_item_id}")
      data_bag_item = Chef::DataBagItem.load(data_bag_name, data_bag_item_id)
      PromoteConfig.use_to
      data_bag_item.save
    end
  end

  # Roles
  PromoteConfig.use_from
  Chef::Log.info("Syncing roles")
  Chef::Role.list.each do |role_name, role_uri|
    PromoteConfig.use_from
    Chef::Log.info("Syncing #{role_name}")
    role = Chef::Role.load(role_name)
    PromoteConfig.use_to
    role.save
  end

  Chef::Log.info("Syncing cookbooks")
  # Get the list of all the cookbooks on the "to" end
  PromoteConfig.use_to
  to_cookbook_list = sanitize_cookbook_list(Chef::REST.new(Chef::Config["chef_server_url"]).get_rest("/cookbooks"))
  Chef::Log.info(to_cookbook_list.inspect)
  from_environment.cookbook_versions.each do |cookbook, constraint|
    constraint =~ /^= (.+)$/
    cookbook_version = $1
    unless to_cookbook_list[cookbook] && to_cookbook_list[cookbook][cookbook_version]
      download_cookbook(cookbook, cookbook_version)
      upload_cookbook(cookbook)
    end
  end
end

print <<-EOH
 ______   _______         ______   _______  _______  _ 
(  ___ \ (  ___  )       (  ___ \ (  ___  )(       )( )
| (   ) )| (   ) |       | (   ) )| (   ) || () () || |
| (__/ / | (___) | _____ | (__/ / | (___) || || || || |
|  __ (  |  ___  |(_____)|  __ (  |  ___  || |(_)| || |
| (  \ \ | (   ) |       | (  \ \ | (   ) || |   | |(_)
| )___) )| )   ( |       | )___) )| )   ( || )   ( | _ 
|/ \___/ |/     \|       |/ \___/ |/     \||/     \|(_)
EOH
