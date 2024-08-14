#!/bin/bash

watch_cmd_linux(){
    inotifywait -q "${files[@]}"
}

watch_cmd_mac(){
    fswatch -1 "$@"
}

watch_cmd=""
case "$(uname)" in
    Darwin) watch_cmd=watch_cmd_mac ;;
    Linux)  watch_cmd=watch_cmd_linux ;;
    *) echo "Unknown operating system : $(uanme)" ; exit 1 ;;
esac

case "$1" in
    -h|--help)
        printf "USAGE: $0 FILE(s) CMD ...
FILE: File to watch for changes on as a COMMA separated list or separated by other IFS chars
CMD: Command to run when FILE is updated.  CMD is eval'd\n"
        exit 0
        ;;
esac
saved_ifs="${IFS}"
IFS="${IFS},"
echo "\$1='$1'"
files=($1)
shift
IFS="${saved_ifs}"
for f in "${files[@]}" ; do
    echo "f='${f}'"
done


run(){
    # Stack overflow answer: https://unix.stackexchange.com/a/146770/161630
    _term() { 
        echo "run process caught a signal"
        kill -TERM "$child_pid" 2>/dev/null
        caught_term=1
    }
    trap _term SIGTERM

    printf "==== event : \033[35m${event}\033[0m ====\n"
    printf "running \033[1m$*\033[0m\n"
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
#
# Tested with VIM.  The inotifywait command takes a file name but it looks
# up the inode number of that file and watches that inode.  The problem with
# vim is that when we save, vim deletes the initial file and creates a new one
# which means that it gets a new inode.  This is why the commented out version
# below with 'inotifywait ${file} | while ... done' doesn't work.  The following
# does work because with every event, we relaunch inotifywait.
#
trap 'if ! kill -TERM ${run_pid} 2>/dev/null ; then echo "exit trap: no process to kill" ; else  wait ${run_pid} ; fi' EXIT

export event
while true ; do
    if ! event=$(${watch_cmd} "${files[@]}") ; then
        echo "Error in inotifywait command"
        exit 1
    fi
    #
    # For long running programs, this is useful.  We run the command asynchronously
    # and go back to waiting for file events.  When we get a new file event,
    # we kill the previous process and start a new one.  This way iwatch can
    # be used to test servers and things of that nature.
    #
    kill ${run_pid} 2>/dev/null
    wait ${run_pid}
    #
    # Use setsid to prevent forwarding of signals to child this way the only
    # signal it can receive is going to be the TERM signal
    # Also note, first argument of a `bash -c '...'` becomes the `$0` of that
    # process.
    #
    setsid bash -c 'run "$@"' "$*" "$@" &
    run_pid=$!
    sleep 0.5
done
