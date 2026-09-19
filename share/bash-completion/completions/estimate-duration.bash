_estimate-duration(){
    local cur prev words cword
    _init_completion || return

    local i
    for ((i=0; i<cword; i++)); do
        if [[ ${words[i]} == "--" ]] ; then
            return 0
        fi
    done

    if [[ "${cur}" == -* ]] ; then
        COMPREPLY=($(compgen -W "--start-timestamp --total-nb --nb-done -h --help" -- "${cur}"))
    fi
}

complete -F _estimate-duration estimate-duration
