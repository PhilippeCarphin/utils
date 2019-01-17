#!/bin/bash

# for at_cmc function
if [ -z $PHILCONFIG ] ; then
    source $PHIL_CONFIG/FILES/initutils
else
    source $PHILCONFIG/FILES/initutils
fi

if [[ "$1" == "-k" ]] ; then
    emacsclient -e '(kill-emacs)'
    exit 0
elif [[ "$1" == "-s" ]] ; then
    emacs --daemon
    exit 0
elif [[ "$1" == "-r" ]] ; then
    emacsclient -e '(kill-emacs)'
    emacs --daemon
    exit 0
fi


terminal=false
if at_cmc ; then
   terminal=true
fi

if $terminal ; then
   options="$options -t"
fi

if [[ -z $1 ]] ; then
    emacsclient $options .
else
    emacsclient $options $@
fi
