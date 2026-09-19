#!/bin/bash # Editor hint

_p.use-profile(){
    local cur prev cword words
    _init_completion || return 1
    local complete_options=true
    local complete_user=true
    # echo ""
    # echo "cword=${cword}, \${words[@]:1:$((cword-1))}=${words[@]:1:cword-1}"
    for w in "${words[@]:1:cword-1}" ; do
        # echo "w=$w"
        case "${w}" in
            --) complete_options=false ;;
            --no-adapt-ps1|-d|--debug|-x|--help) : ;;
            *) complete_user=false ;; # One of the previous arguments is not a known option, that must be a user so don't complete users
        esac
    done
    # echo "complete_user=${complete_user}, complete_options=${complete_options}"
    COMPREPLY=(
        $(${complete_options} && compgen -W "--no-adapt-ps1 -d --debug -x --help -h" -- "${cur}")
        $(${complete_user} && compgen -u -- "${cur}")
    )
}


complete -F _p.use-profile p.use-profile
