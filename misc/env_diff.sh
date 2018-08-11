#!/bin/bash
env_before_file=/tmp/$(whoami)_env_before.txt
env_after_file=/tmp/$(whoami)_env_after.txt
env_analyser dump > $env_before_file
eval $@
env_analyser dump > $env_after_file

env_analyser compare $env_before_file $env_after_file
