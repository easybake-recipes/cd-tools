#!/opt/chef/embedded/bin/ruby
#
# Pin a given environment to the cookbook revisions in the current repository
#

require 'chef/environment'
require 'chef'

Chef::Config.from_file("/var/lib/jenkins/tools/ci-knife.rb")

def pin_env(env, cookbook_versions)
  Chef::Log.info("pinning env: #{env}")
  to = Chef::Environment.load_or_create(env)
  cookbook_versions.each do |cb, version|
    puts "Pinning #{cb} #{version} in #{env}"
    to.cookbook_versions[cb] = version
  end
  to.save
end

cookbook_versions = {}

if Chef::Config['cookbook_path'][0] == ENV['WORKSPACE']
  cookbook_list = [File.expand_path(Chef::Config['cookbook_path'][0])]
else
  cookbook_list = Dir["#{Chef::Config['cookbook_path'][0]}/*"]
end

cookbook_list.each do |cookbook|
  next unless File.directory?(cookbook)
  metadata_file = File.expand_path(File.join(cookbook, "metadata.rb"))
  next unless File.exists?(metadata_file)
  cookbook_name = File.basename(cookbook)
  cookbook_pin = nil
  File.read(metadata_file).each_line do |line|
    case line
    when /^name\s+["'](.+)["'].*$/
      cookbook_name = $1
    when /^version\s+["'](\d+\.\d+\.\d+)["'].*$/
      cookbook_pin = "= #{$1}"
    end
  end
  cookbook_versions[cookbook_name] = cookbook_pin
end

if ARGV[1] == "integration"
  Chef::Environment.list.each do |env, uri|
    if env != ARGV[0] && env =~ /^(dev-|integration)/
      pin_env(env, cookbook_versions)
    end
  end
else
  pin_env(ARGV[0], cookbook_versions)
end

