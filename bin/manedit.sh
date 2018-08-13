#!/bin/bash
manual_to_edit=$1

# NOTE : Option '--where' does not work on OSx
man_link=$(man -w $manual_to_edit)

man_file=$(readlink $man_link)
filename=${man_file%%.man}
org_file=$filename.org

if emacsclient -a false -e 't' >/dev/null ; then
    emacsclient --no-wait $org_file
else
    vim $org_file
 fi
