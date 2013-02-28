File.umask(0022)

%w{/etc/bashrc /etc/profile /etc/csh.cshrc}.each do |shellrc|
  execute "perl -pi -e 's/umask 022/umask 077/g' #{shellrc}" do
    only_if "grep 'umask 022' #{shellrc}"
    action :nothing
  end.run_action(:run)
end
