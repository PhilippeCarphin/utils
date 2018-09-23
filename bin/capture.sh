#!/bin/bash

if ! emacsclient -c -e '(org-capture)' 2>/dev/null; then
   vim ~/Dropbox/Notes/gtd/GTD_InTray.org
fi
