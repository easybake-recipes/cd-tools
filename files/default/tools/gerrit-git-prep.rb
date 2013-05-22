#!/opt/chef/embedded/bin/ruby
#
# Rewrite of git-gerrit-prep.sh in ruby
#

require 'mixlib/shellout'
require 'mixlib/log'

class Glog
  extend Mixlib::Log
end

def run_command(command, return_status=[0])
  s = Mixlib::ShellOut.new(command)
  s.logger = Glog.logger
  s.live_stream = STDOUT
  s.valid_exit_codes = return_status
  s.run_command
  s.error!
  s
end

def merge_change(site, gerrit_project, gerrit_refspec)
  attempts = 0 
  max_attempts = 3
  while attempts < max_attempts
    begin
      run_command("git fetch ssh://jenkins@#{site}:29418/#{gerrit_project}.git #{gerrit_refspec}")
      break
    rescue 
      puts "Git fetch failed - attempt #{attempts} of #{max_attempts}: $!"
    end
    sleep 10
    attempts += 1
  end

  if attempts < max_attempts
    run_command("git merge -s resolve FETCH_HEAD")
  else
    puts "Failed to fetch too many times - giving up."
    exit 2
  end
end

Glog.level = :debug

# GERRIT_CHANGES="gtest-org/test:master:refs/changes/20/420/1^gtest-org/test:master:refs/changes/21/421/1"
# GERRIT_CHANGES="gtest-org/test:master:refs/changes/21/421/1"
def merge_changes(site)
  ENV['GERRIT_CHANGES'].split('^').each do |change|
    change_project, change_branch, change_refspec = change.split(':')
    
    if change_project == ENV['GERRIT_PROJECT'] && change_branch == ENV['GERRIT_BRANCH']
      merge_change(site, change_project, change_refspec)
    end
  end
end

if ARGV[0]
  site = ARGV[0]
else
  puts "The site name(eg 'review.openstack.org') must be the first argument."
  exit 1
end

if ![ "GERRIT_NEWREV", "GERRIT_REFSPEC", "GERRIT_CHANGES" ].map { |v| ENV.has_key?(v) }.include?(true)
  puts "This job may only be triggered by Gerrit."
  exit 1
end

gerrit_ref = ENV['GERRIT_REFSPEC'] || ENV['GERRIT_CHANGES']
gerrit_ref =~ /refs\/changes\/\d+\/(\d+)\/(\d+)$/
change_number = $1

puts "Triggered by https://#{site}/#{change_number}"

pwd = Dir.pwd 
dot_git_dir = File.join(pwd, '.git')
if !File.directory?(dot_git_dir)
  run_command("git clone ssh://jenkins@#{site}:29418/#{ENV['GERRIT_PROJECT']}.git .")
end
begin
  run_command('git remote update')
rescue 
  run_command('git remote update')
end # attempt to work around bug #925790

run_command('git reset --hard')
run_command('git clean -x -f -d -q')

if ENV.has_key?('GERRIT_NEWREV')
  Glog.info("Using GERRIT_NEWREV")
  run_command("git checkout #{ENV['GERRIT_NEWREV']}")
  run_command("git reset --hard #{ENV['GERRIT_NEWREV']}")
  run_command("git clean -x -f -d -q")
else
  run_command("git checkout #{ENV['GERRIT_BRANCH']}")
  run_command("git reset --hard remotes/origin/#{ENV['GERRIT_BRANCH']}")
  run_command("git clean -x -f -d -q")

  if ENV['GERRIT_REFSPEC']
    merge_change(site, ENV['GERRIT_PROJECT'], ENV['GERRIT_REFSPEC']) 
  else
    merge_changes(site)
  end
end
