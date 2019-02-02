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


if [[ -z $1 ]] ; then
    if at_cmc ; then
        emacsclient -nw
    else
        emacsclient -c --no-wait -e '(spacemacs/switch-to-scratch-buffer)'
    fi
else
    if at_cmc ; then
        emacsclient -t $@
    else
        # Unless I specify "-t", always put -c --no-wait.
        # I just always do it like that.
        # Note the space in " $@", and also note that '"* -t"'
        # doesn't work with either single or double quotes..
        if [[ " $@" == *\ -t* ]] ; then
            emacsclient $@
        else
            emacsclient -c --no-wait $@
        fi
    fi
fi

