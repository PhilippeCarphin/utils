#!/usr/bin/env bash

run-with-region-shell(){
    local read_from=$1
    if [[ $1 == - ]] ; then
        read_from="/dev/stdin"
    fi
    local line
    while read line ; do
        if [[ $line == \#* ]] ; then
            if ! ${line#\#} ; then
                return 1
            fi
            continue
        fi

        if ! do-with-region ${line} ; then
            return 1
        fi
    done < ${read_from}
}

do-with-region(){
    local SCROLL_SIZE=8
    local VERBOSE=0
    printf "\033[32m==> Doing \033[1;33m%s\033[0m\n" "$*" >&2

    # Print SCROLL_SIZE lines to make space, then move cursor back up
    # SCROLL_SIZE lines to get it back to where it was
    printf -v spaces "%${SCROLL_SIZE}s"
    printf "%s" "${spaces//?/$'\n'}" >&2
    printf "\033[${SCROLL_SIZE}A" >&2

    #
    # Get cursor position needed to set the scroll region
    # After receiving \033[6n, the terminal emulator will send us
    # our cursor position on /dev/tty in the form \033[<ROW>;<COL>R
    #
    # - Read from /dev/tty in case STDIN is input meant for CMD
    # - Turn off echoing of characters because sometimes (maybe some kind of race)
    #   we see the '[x;yR' on the terminal
    #
    local stty_settings=$(stty -F /dev/tty -g)
    stty -F /dev/tty -echo
    printf "\033[6n" >&2
    read -s -d R response </dev/tty
    pos=${response#*'['}
    row=${pos%;*}
    stty -F /dev/tty "${stty_settings}"

    # Set scroll region to $((row)) $((SCROLL_SIZE-1)):ta
    # \e7 ... \e8 is save ... restore cursor position
    # \e[<START>;<END>r sets the scroll region
    printf "\e7\e[${row};$((row + SCROLL_SIZE - 1))r\e8" >&2

    "$@" >&2
    local status=$?
    if ((status == 0)) ; then
        for ((r=${row}; r<row+SCROLL_SIZE-1; r++)); do
            printf "\033[$r;0H\033[2K" >&2
        done
        printf "\033[$row;H" >&2
        printf "\033[35m==> ... \033[1;32mSUCCESS\033[0m\n" >&2
        printf "\e7\e[r\e8" >&2
        return 0
    else
        printf "\e7\e[r\e8" >&2
        printf "\033[35m==> ... \033[1;31mFAILURE ${status}\033[0m\n" >&2
        return 1
    fi

    # Ensure scroll region is reset if program exits normally or abnormally
}
