#!/opt/chef/embedded/bin/ruby
# 
# Takes a list of globby-asset paths, and for each asset,
# puts together names, versions, and sha256 sum.
#
# Puts the whole lot out in a very globby environment variable

Dir[File.join(ENV['WORKSPACE'], 'pkg')].each do |file|
  File.unlink(file)
end

exit 0
