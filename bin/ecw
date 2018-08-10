#!/bin/bash

filepath=$(which $1); shift
if emacsclient -a false -e 't' >/dev/null ; then
    ec $filepath $@
else
    vim $filepath $@
fi
