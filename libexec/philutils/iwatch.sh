#!/usr/bin/env bash


main(){
    local watch_cmd
    set_watch_cmd

    case "$1" in
        -h|--help) usage ; exit 0 ;;
    esac

    local -a files
    get_filenames "$1" ; shift

    cmd=("$@")
    resolve_percent cmd

    trap 'if ! kill -TERM ${run_pid} 2>/dev/null ; then echo "exit trap: no process to kill" ; else  wait ${run_pid} ; fi' EXIT

    export event_type event_file
    # See [2] for reason why we do a loop instead of `inotifywait -m | ...` or
    # `fswatch | ...`
    while true ; do
        if ! event=($(${watch_cmd} "${files[@]}")) ; then
            echo "Error in inotifywait command"
            exit 1
        fi
        event_type=${event[1]}
        event_file=${event[0]}

        #
        # Disregard some events that are triggered too frequently [1]
        #
        echo "EVENT: ${event[*]}"
        case ${event[1]} in
            ACCESS|OPEN) continue ;;
        esac

        #
        # Run user supplied command asynchronously, wait for it to finish.  The
        # next time an event is received, kill the previous one if before
        # starting a new one.
        #
        kill ${run_pid} 2>/dev/null
        wait ${run_pid}
        bash -c 'run "$@"' "${cmd[*]}" "${cmd[@]}" &
        run_pid=$!

        #
        # Sleep to avoid reacting to groups of events.
        #
        sleep 0.5
    done
}
usage(){
        printf "USAGE: $0 FILE(s) CMD ...
FILE: File to watch for changes on as a COMMA separated list or separated by other IFS chars
CMD: Command to run when FILE is updated.  CMD is eval'd\n"
        exit 0
}

watch_cmd_linux(){
    # -q suppresses startup output.  By default the inotifywait command prints
    # a single event and exits. See [2].
    inotifywait -q "${files[@]}"
}

watch_cmd_mac(){
    # Watch a file, by default, fswatch runs forever and ouputs a line for each
    # event that occurs.  See [2].
    fswatch -1 "$@"
}

#
# Change elements of array by replacing '%^' by the list of files and '%' by
# the first file.  This is inspired by $^ (whole dependency list) and '$<'
# (the first dependency) for Makefiles but with '%' instead of '%<' because
# '%<' would only work inside quotes (otherwise the '<'  would get interpreted
# as a redirection) while '%' and '%^' work outside of quotes.
#
resolve_percent(){
    local -n _to_resolve=$1
    local i e
    for i in ${!_to_resolve[@]} ; do
        e=${_to_resolve[i]}
        e=${e//%^/${files[*]}}
        e=${e//%/${files[0]}}
        _to_resolve[i]=${e}
    done
}

get_filenames(){
    local IFS="${IFS},"
    files=($1)
    #
    # See [1] for why links deserve a warning
    #
    for f in "${files[@]}" ; do
        if [[ -L $f ]] ; then
            printf "\033[33mWARNING\033[0m: file '$f' is a link\n"
        fi
    done
}

set_watch_cmd(){
    case "$(uname)" in
        Darwin) watch_cmd=watch_cmd_mac ;;
        Linux)  watch_cmd=watch_cmd_linux ;;
        *) echo "Unknown operating system : $(uanme)" ; exit 1 ;;
    esac
}


run(){
    # Stack overflow answer: https://unix.stackexchange.com/a/146770/161630
    _term() { 
        echo "run process caught a signal"
        kill -TERM "$child_pid" 2>/dev/null
        caught_term=1
    }
    trap _term SIGTERM
    printf "==== event : \033[35m%s\033[0m ====\n" "${event_file} ${event_type}"
    printf "running \033[1m%s\033[0m\n" "$*"
    bash -c "$*" &
    child_pid=$!
    caught_term=0
    wait ${child_pid}
    exit_code=$?
    if [[ ${caught_term} == 1 ]] ; then
        printf "$0: \033[1;33mTERM\033[0m\n"
        return 0
    fi
    if ! ((exit_code)) ; then
        printf "==$0==: \033[1;32mSUCCESS\033[0m\n\n"
    else
        printf "==$0==: \033[1;31mERROR: ${exit_code}\033[0m\n\n"
    fi
}
export -f run

# [1]: Language servers may open files and any git operation will open most of
#      the files in a repo.
#
#      This has a drawback that seems to only occur when vim opens files through
#      a link.  When vim opens a normal file, when we save the file, the events
#      MOVE_SELF followed by OPEN occur.  However, when opening a link, only
#      the event OPEN happens
#
#      We warn if the one of the files is a link because as long as the real
#      file is opened with vim, it doesn't matter if this script receives the
#      link or the real file, we will see a MOVE_SELF event.
#
# [2]: Tested with VIM.  The inotifywait command takes a file name but it looks
#      up the inode number of that file and watches that inode.  The problem
#      with vim is that when we save, vim deletes the initial file and creates
#      a new one which means that it gets a new inode.  This is why the
#      commented out version below with 'inotifywait ${file} | while ... done'
#      doesn't work.  The following does work because with every event, we
#      relaunch inotifywait.
#
#      I'm not sure if this would be a problem with fswatch because I went with
#      the loop option to make inotifywait work.
#
main "$@"
