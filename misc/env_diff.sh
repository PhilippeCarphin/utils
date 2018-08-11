#!/bin/bash
this_file=$0
while [ -L $this_file ] ; do
    this_file = $(readlink $this_file)
done
this_dir=$(cd -P $(dirname $this_file) > /dev/null && pwd)
env_before_file=/tmp/$(whoami)_env_before.txt
env_after_file=/tmp/$(whoami)_env_after.txt
$this_dir/env_analyser.sh dump > $env_before_file
eval $@
$this_dir/env_analyser.sh dump > $env_after_file

$this_dir/env_analyser.sh compare $env_before_file $env_after_file
