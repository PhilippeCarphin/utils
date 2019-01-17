#!/bin/bash

if ! emacsclient -c -e '(gtd-dashboard)' 2>/dev/null 1>/dev/null ; then
   cd ~/Dropbox/Notes/gtd/
   vim *.org -p
fi
