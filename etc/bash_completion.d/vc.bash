#
# Open commands in $PATH or the file containing the definition of a shell
# function.
#

vc(){
    local file
    if file=$(which ${1} 2>/dev/null) ; then
        vim ${file}
    else
        echo "no '${1}' found in path, looking for shell function"
        open_shell_function "${1}"
    fi
}

################################################################################
# Open the file containing the definition of the supplied shell function
################################################################################
open_shell_function()(

    local shell_function="${1}"

    #
    # The extdebug setting causes `declare -F ${shell_function}` to print
    # '<function> <lineno> <file>'.  Since this function runs in a subshell
    # turning it on here does not affect the outer environment
    #
    shopt -s extdebug

    local info=$(declare -F ${1})
    if [[ -z "${info}" ]] ; then
        echo "No info from 'declare -F' for '${1}'"
        return 1
    fi

    local lineno
    if ! lineno=$(echo ${info} | cut -d ' ' -f 2) ; then
         echo "Error getting line number from info '${info}' on '${1}'"
         return 1
    fi

    local file
    if ! file=$(echo ${info} | cut -d ' ' -f 3) ; then
        echo "Error getting filename from info '${info}' on '${1}'"
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
        if ! which ${c} &>/dev/null ; then
            COMPREPLY[i++]=${c}
        fi
    done
}


whence()(
    local file
    if ! file=$(which ${1} 2>/dev/null) ; then
        declare -F ${1}
    fi
    type ${1}
)

complete -c vc whence
complete -F _open_shell_function open_shell_function

