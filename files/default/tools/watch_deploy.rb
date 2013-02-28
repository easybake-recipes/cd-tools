#!/opt/chef/embedded/bin/ruby
#
# Watch a deployment happen in a given chef environment
#

require 'chef/environment'
require 'chef'
require 'timeout'
require 'open-uri'

Chef::Config.from_file("/var/lib/jenkins/tools/ci-knife.rb")

environment_name = ARGV[0]
app_name = ARGV[1]
role_name = ARGV[2]
interval = ARGV[3].to_i
timeout = ARGV[4].to_i

environment = Chef::Environment.load_or_create(environment_name)
desired_release = environment.override_attributes["apps"][app_name]["desired"]

puts "* Watching for deploy of #{app_name} release #{desired_release}"

Timeout::timeout(timeout) do
  success = false
  while success == false
    q = Chef::Search::Query.new
    response = q.search(:node, "chef_environment:#{environment_name} AND role:#{role_name} AND NOT apps_#{app_name}_status:inactive")
    total_nodes = response[2]
    puts "* #{total_nodes} nodes total in #{environment_name} with role #{role_name}"
    deploy_count = 0
    response[0].each do |n|
      if n['apps'] && n['apps'].has_key?(app_name) && n['apps'][app_name].has_key?("current")
        current_release = n['apps'][app_name]["current"]
        if current_release == desired_release
          puts "** #{n.name} is deployed"
          deploy_count += 1
        else
          puts "** #{n.name} is not deployed"
        end
      else
        puts "** #{n.name} has never deployed #{app_name}"
      end
    end
    if deploy_count == total_nodes
      success = true
    else
      puts "\nSleeping for #{interval}\n"
      sleep interval
    end
  end
end

puts "****"
puts "Deployed #{app_name} #{desired_release} to #{environment_name}"
puts "****"
exit 0

