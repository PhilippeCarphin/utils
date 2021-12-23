#!/bin/bash
files_to_watch="$1"
command_to_run="$2"


# Chmod the change script
if [ -z "$2" ] ; then
    fswatch -0 -o $files_to_watch
else
    if [ -e ./change.sh -o -L ./change.sh ]; then
        echo "$(basename $0): ERROR : There is already a change.sh file"
        exit 1
    fi

    # Put the command to run in a temporary script that will output a purple line
    # between each invocation of the command to run.
    echo "printf \"\033[35m================================================================================\033[0m\n\"
    $2
    exit 0" > change.sh
    chmod u+x change.sh

    # Invoke the filesystem watcher as per the example from $ man fswatch.
    fswatch -0 -o $files_to_watch | xargs -0 -n 1 ./change.sh

    # remove the script.
    rm change.sh
fi
