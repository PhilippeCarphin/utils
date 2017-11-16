#!/bin/bash
if [[ "$1" == "" ]] ; then
	cat ~/.todo.txt
else
	echo "$(date): $1" >> ~/Dropbox/.todo.txt
fi

