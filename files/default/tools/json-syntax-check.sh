#!/bin/bash -x

PATH=/usr/local/bin:$PATH
declare -i RESULT=0
if [ -d ./chef-repo ]; then
  check_dir=./chef-repo
else
  check_dir=.
fi
for x in `find $check_dir -name '*.json'`; do 
  echo "Checking $x"
  jsonlint $x > /dev/null
  RESULT+=$?
done
exit $RESULT
