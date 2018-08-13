#!/bin/bash

if emacsclient -a false -e 't' >/dev/null ; then
    ec -ct $@
else
    vim $@
fi
