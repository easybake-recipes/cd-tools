#!/bin/bash -x

if [ -d ./chef-repo/cookbooks ]; then
  check_dir=./chef-repo/cookbooks
elif [ -d ./cookbooks ]; then
  check_dir=./cookbooks
else
  check_dir=./
fi

/opt/chef/embedded/bin/foodcritic $check_dir $1

