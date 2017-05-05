#!/bin/bash
files_to_watch="$1"
command_to_run="$2"

if [ -e ./change.sh -o -L ./change.sh ]; then
	echo "$(basename $0): ERROR : There is already a change.sh file"
	exit 1
fi

# Put the command to run in a temporary script that will output a purple line
# between each invocation of the command to run.
echo "echo \"$(tput setaf 5)================================================================================$(tput sgr 0)\"
$2
exit 0" > change.sh

# Chmod the change script
chmod u+x change.sh

# Invoke the filesystem watcher as per the example from $ man fswatch.
fswatch "$files_to_watch" | xargs -n1 ./change.sh

# remove the script.
rm change.sh
