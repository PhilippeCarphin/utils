#!/bin/bash
env_before_file=/tmp/$(whoami)_env_before.txt
env_after_file=/tmp/$(whoami)_env_after.txt
env | sort | sed 's/:/\n    /g' > $env_before_file
eval $@
env | sort | sed 's/:/\n    /g' > $env_after_file
vimdiff $env_before_file $env_after_file
rm $env_before_file $env_after_file
