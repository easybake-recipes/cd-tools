if node['platform_family'] == "windows"
  remote_directory "C:/jenkins/tools" do
    source "tools"
    files_backup 10
    files_mode "0755"
  end
else
  remote_directory "/var/lib/jenkins/tools" do
    source "tools"
    files_backup 10
    files_owner "root"
    files_mode "0755"
    owner "root"
    mode "0755"
  end
end

