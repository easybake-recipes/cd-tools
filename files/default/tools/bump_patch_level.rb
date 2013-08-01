#!/opt/chef/embedded/bin/ruby

def bump_patch_level(metadatarb)
  File.open(metadatarb, 'r+') do |f|
    lines = f.readlines
    lines.each do |line|
      if line =~ /^version\s+["'](\d+)\.(\d+)\.(\d+)["'].*$/
        major = $1
        minor = $2
        patch = $3
        new_patch = patch.to_i + 1
        puts "Incrementing #{metadatarb} version from #{major}.#{minor}.#{patch} to #{major}.#{minor}.#{new_patch}"
        line.replace("version          \"#{major}.#{minor}.#{new_patch}\"\n")
      end
    end
    f.pos = 0
    lines.each do |line|
      f.print line
    end
    f.truncate(f.pos)
  end
end

updated = false

# why did we do this? we should be on the branch we want right now!
#if !system("git checkout master")
#  raise "Failed to checkout master"
#end

seen_cookbooks = []

STDIN.each_line do |diff_line|
  if diff_line =~ /^(.)\s+cookbooks\/(.+)/
    next if $1 == "D"
    cookbook = $2.split('/').first
    next if seen_cookbooks.include?(cookbook)
  else
    next
  end
  metadata_file = File.expand_path(File.join("cookbooks", cookbook,
                                        "metadata.rb"))
  bump_patch_level(metadata_file)
  if !system("git add #{metadata_file}")
    raise "Failed to git add #{metdata_file}: #{$?}"
  end
  seen_cookbooks << cookbook
  updated = true
end

# FIXME: this logic for a cookbook repo is a bit flakey
metadata_file = 'metadata.rb'
if File.exists? (metadata_file)
  bump_patch_level(metadata_file)
  if !system("git add #{metadata_file}")
    raise "Failed to git add #{metdata_file}: #{$?}"
  end
  seen_cookbooks << '_thisrepo_' # can we pull the name from the metadata?
  updated = true
end

if updated
  if !system("git commit -m 'Updated patch level for #{seen_cookbooks.join(', ')}'")
    raise "Failed to git commit"
  end

  if ENV['GERRIT_BRANCH'].nil?
    branch="master"
  else
    branch=ENV['GERRIT_BRANCH']
  end

  if !system("git push origin " + branch)
    raise "Failed to git push"
  end
end
