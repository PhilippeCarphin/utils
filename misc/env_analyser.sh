#!/bin/bash
this_file=$0
while [ -L $this_file ] ; do
    this_file=$(readlink $this_file)
done
this_dir=$(cd -P $(dirname $this_file) > /dev/null && pwd)
python3 $this_dir/../misc/env_analyser.py $@
