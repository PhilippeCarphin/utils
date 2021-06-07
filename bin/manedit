#!/bin/bash
if [ -z $1 ] ; then
    echo "$0 : ERROR : Argument required"
    exit 1
fi

manual_to_edit=$1
shift

# NOTE : Option '--where' does not work on OSx
# NOTE : Option '-w' follows links on Linux
man_link=$(man -w $manual_to_edit)
if [ -z $man_link ] ; then
    exit 1;
fi

while [ -L $man_link ] ; do
    man_link=$(readlink $man_link)
done
man_file=$man_link

filename=${man_file%%.man}
org_file=$filename.org

if [ -z $org_file ] ; then
    echo "$0 : ERROR : Could not find org-mode file for $man_to_edit"
    exit 1
fi

if emacsclient -a false -e 't' >/dev/null ; then
    emacsclient $org_file $@
else
    vim $org_file $@
fi
