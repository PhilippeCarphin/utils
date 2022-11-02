#
# Open commands in $PATH or the file containing the definition of a shell
# function.
#

vc(){
    local -r cmd="${1}"
    local file
    if file=$(command which ${cmd} 2>/dev/null) ; then
        vim ${file}
    else
        echo "no '${cmd}' found in path, looking for shell function"
        open_shell_function "${cmd}"
    fi
}

################################################################################
# Open the file containing the definition of the supplied shell function
################################################################################
open_shell_function()(

    local -r shell_function="${1}"

    #
    # The extdebug setting causes `declare -F ${shell_function}` to print
    # '<function> <lineno> <file>'.  Since this function runs in a subshell
    # turning it on here does not affect the outer environment
    #
    shopt -s extdebug

    local info=$(declare -F ${shell_function})
    if [[ -z "${info}" ]] ; then
        echo "No info from 'declare -F' for '${shell_function}'"
        return 1
    fi

    local lineno
    if ! lineno=$(echo ${info} | cut -d ' ' -f 2) ; then
         echo "Error getting line number from info '${info}' on '${shell_function}'"
         return 1
    fi

    local file
    if ! file=$(echo ${info} | cut -d ' ' -f 3) ; then
        echo "Error getting filename from info '${info}' on '${shell_function}'"
        return 1
    fi

    vim ${file} +${lineno}
)

_open_shell_function(){
    local cur prev words cword
    _init_completion || return

    local candidates=( $(compgen -c ${cur}) )
    local i=0
    for c in "${candidates[@]}" ; do
        if ! command which ${c} &>/dev/null ; then
            COMPREPLY[i++]=${c}
        fi
    done
}


whence()(

    local -r cmd="${1}"

    shopt -s extdebug
    local file
    if ! file=$(command which ${cmd} 2>/dev/null) ; then
        declare -F ${cmd}
    fi
    type ${cmd}
)

complete -c vc whence
complete -F _open_shell_function open_shell_function

