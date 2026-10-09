#!/bin/bash # Editor hint

#
# Quasi-copy of the function that currently resides only in my tests repo in
# BASH_tests/completion/_tilde.sh
#
_usernames(){
    local cur=${COMP_WORDS[COMP_CWORD]}
    #
    # Create parallel arrays of users and full names while also finding the
    # longest user and eliminating "deactivated" users.
    #
    local max_user=0 users=() fullnames=() user name home shell
    while IFS=: read user _ _ _ name home shell ; do
        if [[ ${shell} == /bin/false ]] ; then
            continue
        fi
        if ((${#user} > max_user)) ; then
            max_user=${#user}
        fi
        users+=("$user")
        fullnames+=("$name")
    done < <(compgen -u ${cur} | xargs getent passwd)
    max_user=$((max_user+1)) # for the `~` that we are adding back

    #
    # Inject descriptions into COMPREPLY except if there is only one result
    # (otherwise the description will also be added to the command line)
    #
    if ((${#users[@]} > 1)) ; then
        for ((i=0;i<${#users[@]};i++)) ; do
            local comp
            printf -v comp "%-${max_user}s (%s)" "${users[i]}" "${fullnames[i]//\//-}"
            COMPREPLY+=("${comp}")
        done
    else
        for u in "${users[@]}" ; do
            COMPREPLY+=("$u")
        done
    fi

    return $((${#COMPREPLY[@]} == 0))
}

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
    COMPREPLY=($(${complete_options} && compgen -W "--no-adapt-ps1 -d --debug -x --help -h" -- "${cur}"))
    _usernames
}


complete -F _p.use-profile p.use-profile
