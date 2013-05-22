#!/opt/chef/embedded/bin/ruby

require 'mixlib/shellout'
require 'mixlib/log'

class Glog
  extend Mixlib::Log
end

STDOUT.sync = true

pkg_name = ARGV[0]
pkg_real_archive = ARGV[1]
pkg_version = ENV['BUILD_ID'].gsub('-', '_')
pkg_dir = File.join(ENV['WORKSPACE'], "pkg")
pkg_filename = File.join(pkg_dir, "#{pkg_name}-#{pkg_version}.zip")

FileUtils.mkdir_p(pkg_dir)

if File.exists?(pkg_real_archive)
  FileUtils.copy(pkg_real_archive, pkg_filename)
else
  raise "Cannot find #{pkg_real_archive} to copy it to #{pkg_filename}"
end

exit 0
