#!/opt/chef/embedded/bin/ruby

require 'chef/environment'
require 'chef/data_bag'
require 'chef/data_bag_item'
require 'chef/json_compat'
require 'chef'

Chef::Config.from_file("/var/lib/jenkins/tools/ci-knife.rb")

environment_name = ARGV[0]
app_name = ARGV[1]
build_id = ENV['ASSET_BUILD_ID']

# M4-service!:!1.0.38-2012-08-15_16-45-47!:!M4-service-1.0.38-2012-08-15_16-45-47.war!:!80bbfc637912bdb3a0220c77f83679b6d8299ba63c6dc9f0b94f01ba59e4f83a!x!M4-sync!:!1.0.38-2012-08-15_16-45-47!:!M4-sync-1.0.38-2012-08-15_16-45-47.war!:!4d72c3ea934c267c2a011238dd49f05b597f86c099eef0098b1c5c44c7ba706a!x!M4-remote-tests!:!1.0.38-2012-08-15_16-45-47!:!M4-remote-tests-1.0.38-2012-08-15_16-45-47.war!:!dac23d89cd55478f7141de46ba78ad97ddc96887cd10d80580eeaa9def1cad09
#

assets = {}
ENV['ASSETS'].split("!x!").each do |asset_pack|
  av = asset_pack.split("!:!")
  name = av[0]
  version = av[1]
  filename = av[2]
  shasum = av[3]
  assets[name] = { "version" => version, "filename" => filename, "checksum" => shasum, "build_url" => ENV['ASSET_BUILD_URL'] }
end

# Accept that the data bag might already exist, so the save returns a 409
begin
  repo_app_db = Chef::DataBag.new
  repo_app_db.name "repo_#{app_name}"
  repo_app_db.save
rescue Net::HTTPServerException => e
  raise e unless ["409", "405"].include? e.response.code
end

repo_app_release = Chef::DataBagItem.new
repo_app_release.data_bag "repo_#{app_name}"
repo_app_release["id"] = build_id
repo_app_release["build_url"] = ENV['BUILD_URL']
ENV.each do |key, value|
  next if key !~ /^GERRIT/
  repo_app_release[key.downcase] = value
end
repo_app_release["assets"] = assets

deploy_config_file = File.join(ENV['WORKSPACE'], "deploy-config.json")

if File.exists?(deploy_config_file)
  repo_app_release["config"] = Chef::JSONCompat.from_json(IO.read(deploy_config_file))
end
repo_app_release.save

# Update the environment after the data bag goes up
to = Chef::Environment.load_or_create(environment_name)
puts to.inspect
to.override_attributes["apps"] ||= {}
to.override_attributes["apps"][app_name] ||= {}
to.override_attributes["apps"][app_name]["desired"] = build_id
to.save

