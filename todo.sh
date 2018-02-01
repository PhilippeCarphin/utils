#!/bin/bash

TODO_FILE=~/Dropbox/todo.txt
if [[ "$1" == -o ]] || [[ "$1" == --open ]] ; then
	vim $TODO_FILE
else
	if [[ "$1" == "" ]] ; then
		echo "cat $TODO_FILE (use --open to open file in vim)"
		cat $TODO_FILE
	else
		echo "$(date): $1" >> $TODO_FILE
	fi
fi
