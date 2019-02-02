#!/bin/bash

argument_found=false
for f in "$@" ; do
    if [[ $f == -* ]] ; then
        args=$"$args $f"
    else
        if ! which $f > /dev/null 2>&1 ; then
            which $f
            exit 1;
        fi
        args="$args $(which $f)"
        argument_found=true
    fi
done

if ! $argument_found ; then
    echo "ERROR : You must supply the name of a program to search for"
fi

if emacsclient -a false -e 't' >/dev/null ; then
    emacsclient -t $args
else
    vim $filepath $@
fi
