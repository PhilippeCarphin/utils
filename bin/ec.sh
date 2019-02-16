#!/bin/bash

# for at_cmc function
if [ -z $PHILCONFIG ] ; then
    source $PHIL_CONFIG/FILES/initutils
else
    source $PHILCONFIG/FILES/initutils
fi

function main(){
    if [[ "$1" == "-k" ]] ; then
        emacsclient -e '(kill-emacs)'
        exit 0
    elif [[ "$1" == -K ]] ; then
        kill_emacs_by_pid
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
}

function kill_emacs_by_pid(){
    if [[ $(uname) == Darwin ]] ; then
        emacs_process=$(ps -aupcarphin| grep Emacs.app | grep -v grep)
        emacs_pid=$(awk '{print $2;}' <<< $emacs_process)
    else
        echo "Not implemented for linux"
        exit 1
    fi

    if [[ -z $emacs_process ]] ; then
        echo "No emacs process found"
        return 1
    fi

    echo "emacs_process: $(awk '{print $2 " " $5;}' <<< $emacs_process)"
    echo -n "Kill this process? (y/n): "; read answer

    if [[ -z $answer ]] ; then
        return
    fi

    if [[ -z $answer ]] || ! ([[ $answer == y ]] || [[ $answer == Y ]]) ; then
        return
    fi

    echo kill $emacs_pid
    kill $emacs_pid
}

main $@
