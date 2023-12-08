#
# Open commands in $PATH or the file containing the definition of a shell
# function.
#

vc(){
    local cmd="${1}"
    local alias_str
    if [[ -n ${VC_EXPAND_ALIASES} ]] ; then
        if alias_str=$(alias ${cmd} 2>/dev/null) ; then
            # output of alias is "alias <name>='<alis'"
            local alias_def=${alias_str#*=}
            local alias_name=${alias_str%%=*}
            local alias_def_words=($( eval echo ${alias_def} ) )
            local alias_cmd=${alias_def_words[0]}
            cmd=${alias_def_words[0]}
            echo "${FUNCNAME[0]}: Expanded ${alias},  now looking for ${cmd}" >&2
        fi
    fi

    echo "${FUNCNAME[0]}: Looking for shell function '${cmd}'" >&2
    open_shell_function "${cmd}"

    echo "${FUNCNAME[0]}: Looking for executable '${cmd}' in PATH" >&2
    local file
    if file=$(command which ${cmd} 2>/dev/null) ; then
        vim ${file}
        return
    fi

    if ! shopt -q sourcepath ; then
        return 0
    fi

    echo "${FUNCNAME[0]}: Looking for sourceable file in $PATH" >&2
    file="$(find -L $(echo $PATH | tr ':' ' ') -name "${cmd}" ! -executable -type f -print -quit)"
    if [[ -n "${file}" ]] ; then
        echo ${file}
        vim ${file}
        return
    fi
}
        fi
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

    if alias ${cmd} 2>/dev/null ; then
        return
    fi

    shopt -s extdebug
    if declare -F ${cmd} ; then
        return
    fi

    local file
    if file=$(command which ${cmd} 2>/dev/null) ; then
        echo "${file}"
        return
    fi

    file="$(find -L $(echo $PATH | tr ':' ' ') -name "${cmd}" -type f)"
    if [[ -n "${file}" ]] ; then
        echo ${file}
        return
    fi

)

complete -c vc whence
complete -F _open_shell_function open_shell_function

