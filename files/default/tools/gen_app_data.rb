#!/opt/chef/embedded/bin/ruby
# 
# Takes a list of globby-asset paths, and for each asset,
# puts together names, versions, and sha256 sum.
#
# Puts the whole lot out in a very globby environment variable

require 'digest'

def checksum_file(file)
  File.open(file, 'rb') { |f| checksum_io(f, Digest::SHA256.new) }
end

def checksum_io(io, digest)
  while chunk = io.read(1024 * 8)
    digest.update(chunk)
  end
  digest.hexdigest
end

assets = [] 
ARGV.each do |dir_pattern|
  Dir[dir_pattern].each do |file_path|
    file_name = File.basename(file_path)
    case file_path
    when /\.rpm$/
      file_name =~ /^(.+)-(\d{4}_\d{2}_\d{2}_\d{2}_\d{2}_\d{2}-1)\..+\.rpm$/
      name = $1
      version = $2
    when /\.war$/
      case file_name
      when /^(.+)-(\d+\.\d+\.\d+-\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2})\.war/
        name = $1
        version = $2
      when /^(.+)-(\d+\.\d+\.\d+-SNAPSHOT).*\.war/
        name = $1
        version = $2
      end
    when /\.tgz$/
      file_name =~ /^(.+)-(\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}).tgz$/
      name = $1
      version = $2
    when /\.zip$/
      # MobileSecure-2013_02_14_21_04_12.zip
      file_name =~ /^(.+)-(\d{4}_\d{2}_\d{2}_\d{2}_\d{2}_\d{2})\.zip/
      name = $1
      version = $2
    end
    checksum = checksum_file(file_path)
    assets << "#{name}!:!#{version}!:!#{file_name}!:!#{checksum}"
  end
end

File.open(File.join(ENV['WORKSPACE'], "sync.properties"), "w") do |f|
  f.puts "ASSETS = #{assets.join('!x!')}"
  build_id = ENV['BUILD_ID'].gsub('-', '_')
  f.puts "ASSET_BUILD_ID = #{build_id}"
  f.puts "ASSET_BUILD_URL = #{ENV['BUILD_URL']}"
end

