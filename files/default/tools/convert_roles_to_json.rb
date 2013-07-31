#!/opt/chef/embedded/bin/ruby

require 'chef'
require 'chef/role'

Dir["roles/*.rb"].each do |role|
  r = Chef::Role.new
  r.from_file(role)
  name = File.basename(role)
  name.gsub!(/\.rb$/, ".json")
  File.open("roles/#{name}", "w") do |f|
    f.puts JSON.pretty_generate(r)
  end
end
