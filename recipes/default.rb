#
# Cookbook Name:: cd-tools
# Recipe:: default
#
# Copyright 2012, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

include_recipe "jenkins"

case node.platform_family
when /debian/
  %w{ttf-dejavu ttf-dejavu-core ttf-dejavu-extra}
else
  %w{dejavu-fonts-common dejavu-lgc-sans-mono-fonts dejavu-sans-fonts dejavu-sans-mono-fonts dejavu-serif-fonts}
end.each do |font_pkg|
  package font_pkg
end

include_recipe "cd-tools::tools"

slaves = [] 
search(:node, "role:jenkins-windows-slave") do |n|
  slave = n["jenkins"]["node"].to_hash 
  slave['name'] = n["fqdn"]
  slave['launcher'] ||= {}
  slave['launcher']['host'] = n['fqdn']
  slaves << slave
end

# Drop off the jenkins configuration files
template "/var/lib/jenkins/config.xml" do
  source "config.xml.erb"
  owner "jenkins"
  group "jenkins"
  mode "0644"
  variables(
    "dev_views" => { },
    "pipeline_views" => { },
    "app_views" => { },
    "slaves" => slaves 
  )
  notifies :restart, "service[jenkins]"
end

cookbook_file "/var/lib/jenkins/plugins/gerrit-trigger.hpi" do
  source "gerrit-trigger.hpi"
  owner "jenkins"
  group "jenkins"
  mode "0644"
end

template "/var/lib/jenkins/gerrit-trigger.xml" do
  source "gerrit-trigger.xml.erb"
  owner "jenkins"
  group "jenkins"
  mode "0644"
end

template "/var/lib/jenkins/hudson.plugins.warnings.WarningsPublisher.xml" do
  source "hudson.plugins.warnings.WarningsPublisher.xml.erb"
  owner "jenkins"
  group "jenkins"
  mode "0644"
end

template "/var/lib/jenkins/hudson.plugins.throttleconcurrents.ThrottleJobProperty.xml" do
  source "hudson.plugins.throttleconcurrents.ThrottleJobProperty.xml.erb"
  owner "jenkins"
  group "jenkins"
  mode "0644"
end

gem_package "knife-essentials" do
  gem_binary "/opt/chef/embedded/bin/gem"
end

file "/var/lib/jenkins/.gitconfig" do
  owner "jenkins"
  mode "0644"
  content <<-EOH
[user]
	email = #{node['cd-tools']['jenkins']['git_email']}
	name = #{node['cd-tools']['jenkins']['git_name']}
EOH
end

node['cd-tools']['jenkins']['pipeline'].each_index do |i|

  Chef::Log.error(node['cd-tools']['jenkins']['pipeline'].inspect)
  if i == 0
    promote_from = "integration"
  else
    promote_from = node['cd-tools']['jenkins']['pipeline'][i - 1]
  end
  penv = node['cd-tools']['jenkins']['pipeline'][i]

  jct = resources("template[/var/lib/jenkins/config.xml]")
  jct.variables["pipeline_views"][penv] = "^#{penv}-.+"

  job_directory = "/var/lib/jenkins/jobs/#{penv}-deploy"

  directory job_directory do
    owner "jenkins"
    group "jenkins"
    mode "0755"
    recursive true
  end

  template File.join(job_directory, "config.xml") do
    source "deploy.xml.erb"
    owner "jenkins"
    group "jenkins"
    mode "0644"
    notifies :restart, "service[jenkins]"
    variables(
      :promote_from => promote_from,
      :name => penv,
      :apps => {},
      :manual => node['cd-tools']['jenkins']['manual_steps'].include?(penv)
    ) 
  end

  if penv != "integration"
    job_directory = "/var/lib/jenkins/jobs/#{penv}-promote"

    directory job_directory do
      owner "jenkins"
      group "jenkins"
      mode "0755"
      recursive true
    end

    template File.join(job_directory, "config.xml") do
      source "promote.xml.erb"
      owner "jenkins"
      group "jenkins"
      mode "0644"
      notifies :restart, "service[jenkins]"
      variables(
        :promote_from => promote_from,
        :chef_server_url => node['cd-tools']['jenkins']['chef_server_url'],
        :node_name => node['cd-tools']['jenkins']['node_name'],
        :client_key => node['cd-tools']['jenkins']['client_key'],
        :name => penv,
        :manual => node['cd-tools']['jenkins']['manual_steps'].include?(penv)
      ) 
    end
  end
end

ger_host = node['cd-tools']['gerrit']['hostname']
ger_admin = node['cd-tools']['gerrit']['admin_user']
# ger_admin_pass = Chef::EncryptedDataBagItem.load("cd_credentials", ger_admin)['password']
# base64_creds = Base64.encode64("#{ger_admin}:#{ger_admin_pass}")

if node['cd-tools']['stash']
  stash_host = node['cd-tools']['stash']['hostname']
  stash_project = node['cd-tools']['stash']['project']
  create_url = "https://#{stash_host}/rest/api/1.0/projects/#{stash_project}/repos"
end

search(:chef_pipelines, "*:*") do |pipeline|
  execute "ssh -p 29418 -o 'StrictHostKeyChecking no' #{ger_admin}@#{ger_host} gerrit create-project --require-change-id --name #{pipeline['id']}" do
    user node['gerrit']['username']
    creates "#{node['gerrit']['site_path']}/git/#{pipeline['id']}.git"
  end

  # Disabling stash for now
  # if node['cd-tools']['stash']
  #   http_request "create #{pipeline['id']} stash repo" do
  #     action :post
  #     url create_url
  #     message name: pipeline['id']
  #     # Not idempotent yet
  #     # not_if "curl -k #{create_url}"
  #     ignore_failure true
  #     headers({"AUTHORIZATION" => "Basic #{base64_creds}"})
  #   end
  # end


  jct = resources("template[/var/lib/jenkins/config.xml]")
  jct.variables["dev_views"]["dev-#{pipeline['id']}"] = "#{pipeline['id']}-gate-syntax"

  %w{check-syntax check-foodcritic gate-syntax gate-chef-sync promote-integration}.each do |job_partial|
    job_directory = "/var/lib/jenkins/jobs/#{pipeline['id']}-#{job_partial}"

    directory job_directory do
      owner "jenkins"
      group "jenkins"
      mode "0755"
      recursive true
    end
    
    template File.join(job_directory, "config.xml") do
      source "#{job_partial}.xml.erb"
      owner "jenkins"
      group "jenkins"
      mode "0644"
      notifies :restart, "service[jenkins]"
      variables(:job => pipeline, :pipeline_type => "chef")
    end
  end
end

search(:app_pipelines, "*:*") do |pipeline|
  execute "ssh -p 29418 -o 'StrictHostKeyChecking no' #{ger_admin}@#{ger_host} gerrit create-project --require-change-id --name #{pipeline['id']}" do
    user node['gerrit']['username']
    creates "#{node['gerrit']['site_path']}/git/#{pipeline['id']}.git"
  end

  if node['cd-tools']['stash']
    http_request "create #{pipeline['id']} stash repo" do
      action :post
      url create_url
      message name: pipeline['id']
      # Not idempotent yet
      # not_if "curl -k #{create_url}"
      ignore_failure true
      headers({"AUTHORIZATION" => "Basic #{base64_creds}"})
    end
  end

  jct = resources("template[/var/lib/jenkins/config.xml]")
  jct.variables["dev_views"]["dev-#{pipeline['id']}"] = "#{pipeline['id']}-gate-syntax"
  jct.variables["app_views"]["#{pipeline['id']}-status"] = ".+-#{pipeline['id']}-.+"

  %w{check-syntax check-foodcritic check-unit-tests gate-syntax gate-release gate-chef-sync promote-integration}.each do |job_partial|
    job_directory = "/var/lib/jenkins/jobs/#{pipeline['id']}-#{job_partial}"

    directory job_directory do
      owner "jenkins"
      group "jenkins"
      mode "0755"
      recursive true
    end
    
    template File.join(job_directory, "config.xml") do
      owner "jenkins"
      group "jenkins"
      mode "0644"
      notifies :restart, "service[jenkins]"
      if pipeline.has_key?("maven") && (job_partial == "gate-release" || job_partial == "check-unit-tests")
        source "#{job_partial}-maven.xml.erb"
      else
        source "#{job_partial}.xml.erb"
      end
      variables(:job => pipeline, :pipeline_type => "app")
    end
  end

  pipeline['deploy_pattern'].each do |deploy_env, legs|
    if deploy_env == "dev"
      job_name = "#{pipeline['id']}-#{deploy_env}-deploy"
      job_directory = "/var/lib/jenkins/jobs/#{job_name}"

      directory job_directory do
        owner "jenkins"
        group "jenkins"
        mode "0755"
        recursive true
      end

      dpipe = template File.join(job_directory, "config.xml") do
        source "deploy.xml.erb"
        owner "jenkins"
        group "jenkins"
        mode "0644"
        notifies :restart, "service[jenkins]"
        variables(:deploy_env => deploy_env, :name => pipeline['id'], :legs => [])
      end
    else
      begin
        dpipe = resources("template[/var/lib/jenkins/jobs/#{deploy_env}-deploy/config.xml]")
      rescue Chef::Exceptions::ResourceNotFound
        raise "Define #{deploy_env} as a node['cd-tools']['jenkins']['pipeline'], or fix your app data bag"
      end
    end

    legs.each do |leg|
      %w{deploy functional-tests}.each do |job_type|
        if deploy_env == "dev"
          job_name = "#{pipeline['id']}-#{deploy_env}-#{leg}-#{job_type}"
          promote_from = "#{deploy_env}-#{pipeline['id']}"
          dpipe.variables[:legs] << job_name 
        else
          job_name = "#{deploy_env}-#{pipeline['id']}-#{leg}-#{job_type}"
          promote_from = deploy_env
          dpipe.variables[:apps][pipeline['id']] ||= []
          dpipe.variables[:apps][pipeline['id']] << job_name 
        end

        job_directory = "/var/lib/jenkins/jobs/#{job_name}"

        directory job_directory do
          owner "jenkins"
          group "jenkins"
          mode "0755"
          recursive true
        end

        template File.join(job_directory, "config.xml") do
          if pipeline.has_key?("maven")
            source "app-#{job_type}-maven.xml.erb"
          else
            source "app-#{job_type}.xml.erb"
          end
          owner "jenkins"
          group "jenkins"
          mode "0644"
          notifies :restart, "service[jenkins]"
          variables(
            :job => pipeline, 
            :promote_from => promote_from,
            :promote_to => "#{deploy_env}-#{pipeline['id']}-#{leg}",
            :leg => leg, 
            :pipeline_type => "app"
          ) 
        end
      end
    end 
  end
end

