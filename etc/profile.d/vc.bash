#
# Open commands in $PATH or the file containing the definition of a shell
# function.
#
_vc_usage(){
    cat <<-EOF
	usage: vc CMD

	Open file where CMD is defined.  CMD can be
	- A shell function: vc will open the file where the function is defined
	  at the first line of the function
	- An executable script in PATH: vc will open the file
	- A non-executable file in PATH if the shell option 'sourcepath' is active.
	I don't know what vc means, I named it that because of the stack overflow
	question that inspired me to make this tool.
	EOF
}

vc(){
    if [[ "$1" == "--help" ]] ; then
        _vc_usage
        return 0
    fi
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
            echo "${FUNCNAME[0]}: Expanded '${alias_str}', now looking for '${cmd}'" >&2
        fi
    fi

    echo "${FUNCNAME[0]}: Looking for shell function '${cmd}'" >&2
    open_shell_function "${cmd}" ; case $? in
        0) return 0 ;; # We're back from opening the shell function
        1) ;; # cmd is not a shell function, try other things
        2) return 1 ;; # ${cmd} is a shell function but its file doesn't exist
    esac

    echo "${FUNCNAME[0]}: Looking for executable '${cmd}' in PATH" >&2
    local file
    if file=$(command which ${cmd} 2>/dev/null) ; then
        echo "${FUNCNAME[0]}: ${cmd} is '${file}' from PATH" >&2
        vim ${file}
        return
    fi

    if ! shopt -q sourcepath ; then
        return 0
    fi

    echo "${FUNCNAME[0]}: Looking for sourceable file in PATH" >&2
    file="$(find -L $(echo $PATH | tr ':' ' ') -name "${cmd}" ! -executable -type f -print -quit)"
    if [[ -n "${file}" ]] ; then
        echo "${FUNCNAME[0]}: ${cmd} is non-executable file '${file}' from PATH" >&2
        vim ${file}
        return
    fi
}

# Sourceable here means
# - not executable `compgen -c` will pick up executables from PATH anyway
#   and it reduces the number of candidates to run the `file` command on.
# - ASCII text Note: running `file` is the most time consuming step so
#   it should be done only on the candidates that have passed all of the
#   other checks.
_vc_add_path_sourceable(){
    _vc_add_path_sourceable_shell_wildcard
}
#
# Doesn't work if there are two colons together in PATH, this causes
# an empty string to be passed to find
#
_vc_add_path_sourceable_find(){
    local IFS=$': \n'
    for f in $(find -L ${PATH} -maxdepth 1 -name "${cur}*" ! -executable -readable) ; do
        local file_result="$(file -L ${f})"
        if ! ( [[ "${file_result}" == *ASCII* ]] || [[ "${file_result}" == *UTF-8* ]] ) ; then
            continue
        fi
        COMPREPLY+=(${f##*/})
    done
}
_vc_add_path_sourceable_shell_wildcard(){
    local IFS=:
    for p in ${PATH} ; do {
        local IFS=$'\n'
        for f in ${p}/* ; do
            if ! [[ ${f} == ${p}/${cur}* ]] ; then
                continue
            fi
            if [[ -x ${f} ]] ; then
                continue
            fi
            local file_result="$(file -L ${f})"
            if ! ( [[ "${file_result}" == *ASCII* ]] || [[ "${file_result}" == *UTF-8* ]] ) ; then
                continue
            fi
            COMPREPLY+=(${f##*/})
        done
    } done
}


# Two different methods.  One getting candidates using find and one using shell
# wildcard expansion.  Both methods perform similarily however it is good to
# note that when XTRACE is on, the wildcard one is much slower than the
# find one because there is simply more tracing going on.  However, the find
# one seems to use significantly more system time and the shell one seems
# to take much more user time.  Both end up with similar real time.
_vc_test_add_path_sourceable(){
    local cur=s
    COMPREPLY=()
    time _vc_add_path_sourceable_find
    echo "${COMPREPLY[*]}"
    echo "========================================"
    COMPREPLY=()
    time _vc_add_path_sourceable_shell_wildcard
    echo "${COMPREPLY[*]}"
}

_vc(){
    local cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=($(compgen -c -- "${cur}"))
    if shopt -q sourcepath ; then
        _vc_add_path_sourceable
    fi
}

################################################################################
# Open the file containing the definition of the supplied shell function
################################################################################
open_shell_function(){
    (

        local -r shell_function="${1}"

        #
        # The extdebug setting causes `declare -F ${shell_function}` to print
        # '<function> <lineno> <file>'.  Since this function runs in a subshell
        # turning it on here does not affect the outer environment
        #
        shopt -s extdebug

        local info=$(declare -F ${shell_function})
        if [[ -z "${info}" ]] ; then
            echo "vc: No info from 'declare -F' for '${shell_function}'"
            return 1
        fi

        local lineno
        if ! lineno=$(echo ${info} | cut -d ' ' -f 2) ; then
             echo "vc: Error getting line number from info '${info}' on '${shell_function}'"
             return 1
        fi

        local file
        if ! file=$(echo ${info} | cut -d ' ' -f 3) ; then
            echo "vc: Error getting filename from info '${info}' on '${shell_function}'"
            return 1
        fi
        if [[ "${file}" != /* ]] ; then
            echo "vc: Info: file '${file}' is a relative path.  This will only work if run from the directory where the original source command was run" >&2
        fi

        if ! [[ -e "${file}" ]] ; then
            echo "vc: Error: '${cmd}' is a shell function from '${file}' which does not exist" >&2
            return 2
        fi

        echo "vc: Opening '${file}'"
        vim ${file} +${lineno}
    )
}

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

    local -r cmd=$1

    if alias ${cmd} 2>/dev/null ; then
        : return
    fi

    shopt -s extdebug
    local func
    if func=$(declare -F ${cmd}) ; then
        echo "${func}"
        : return
    fi

    local file
    if file=$(command which ${cmd} 2>/dev/null) ; then
        echo "${file}"
        : return
    fi

    file="$(find -L $(echo $PATH | tr ':' ' ') -name "${cmd}" ! -executable -type f)"
    if [[ -n "${file}" ]] ; then
        echo ${file}
        : return
    fi

)

complete -F _vc vc whence
complete -F _open_shell_function open_shell_function

