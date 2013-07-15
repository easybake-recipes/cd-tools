#!/opt/chef/embedded/bin/ruby

require 'mixlib/shellout'
require 'mixlib/log'

class Glog
  extend Mixlib::Log
end

STDOUT.sync = true

pkg_name = ARGV[0]
pkg_path = ARGV[1..-1].join(" ")
pkg_version = ENV['BUILD_ID'].gsub('-', '_')
pkg_dir = File.join(ENV['WORKSPACE'], "pkg")
pkg_filename = File.join(pkg_dir, "#{pkg_name}-#{pkg_version}.zip")

FileUtils.mkdir_p(pkg_dir)

if File.exists?('C:\7-zip\7z.exe')
  command = "C:\\7-zip\\7z.exe a -tzip -xr!pkg #{pkg_filename} #{pkg_path}"
  s = Mixlib::ShellOut.new(command)
else
  command = "zip -R #{pkg_filename} #{pkg_path}"
  s = Mixlib::ShellOut.new(command)
end

Glog.level = :debug
s.logger = Glog.logger
s.live_stream = STDOUT
s.run_command
s.error!
s

exit 0
