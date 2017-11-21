#!/bin/bash
TODO_FILE=~/Dropbox/todo.txt
if [[ "$1" == "" ]] ; then
	cat $TODO_FILE
else
	echo "$(date): $1" >> $TODO_FILE
fi

