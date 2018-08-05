#!/bin/bash
env_before_file=/tmp/$(whoami)_env_before.txt
env_after_file=/tmp/$(whoami)_env_after.txt
python3 ~/Documents/GitHub/utils/bin/env_analyser.py dump > $env_before_file
eval $@
python3 ~/Documents/GitHub/utils/bin/env_analyser.py dump > $env_after_file

python3 ~/Documents/GitHub/utils/bin/env_analyser.py compare $env_before_file $env_after_file
