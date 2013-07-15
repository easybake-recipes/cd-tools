
git "/opt/metarepo" do
  repository "http://github.com/adamhjk/metarepo"
  action :sync
  notifies :run, "execute[bundle-install-metarepo]", :immediately
end

execute "bundle-install-metarepo" do
  command "/opt/chef/embedded/bin/bundle install"
  cwd "/opt/metarepo"
  action :nothing
end
