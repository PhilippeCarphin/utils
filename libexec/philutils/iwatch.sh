#!/bin/bash

case "$1" in
    -h|--help)
        printf "USAGE: $0 FILE CMD ...
FILE: File to watch for changes on.
CMD: Command to run when FILE is updated.  CMD is eval'd\n"
        exit 0
        ;;
esac
file=$1; shift

#
# Tested with VIM.  The inotifywait command takes a file name but it looks
# up the inode number of that file and watches that inode.  The problem with
# vim is that when we save, vim deletes the initial file and creates a new one
# which means that it gets a new inode.  This is why the commented out version
# below with 'inotifywait ${file} | while ... done' doesn't work.  The following
# does work because with every event, we relaunch inotifywait.
#
while true ; do
    event=$(inotifywait -q ${file})
    printf "==== event : \033[35m${event}\033[0m ====\n"
    printf "running \033[1m$*\033[0m\n"
    eval "$@"
    exit_code=$?
    if ! ((exit_code)) ; then
        printf "$0: \033[1;32mSUCCESS\033[0m\n\n"
    else
        printf "$0: \033[1;31mERROR: ${exit_code}\033[0m\n\n"
    fi
    sleep 1
done

# Events: move_self, attrib, delete_sel
# # inotifywait -q -m -e move_self ${file} \
# inotifywait -q -m ${file} \
#     | while read -r filename event; do
#         echo "filename=${filename}, event=${event}"
#         printf "running \033[1m$*\033[0m\n"
#         "$@"         # or "./$filename"
#     done

