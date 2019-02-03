#!/bin/bash

if [[ $1 == "--open-file" ]] ; then
    open_file=t
else
    open_file=nil
fi


emacsclient -e "(org-capture-terminal-command $open_file)"
