#!/usr/bin/env bash
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
    open-shell-function "${cmd}" ; case $? in
        0) return 0 ;; # We're back from opening the shell function
        1) ;; # cmd is not a shell function, try other things
        2) return 1 ;; # ${cmd} is a shell function but its file doesn't exist
    esac

    echo "${FUNCNAME[0]}: Looking for executable '${cmd}' in PATH" >&2
    local file
    if file=$(command which ${cmd} 2>/dev/null) ; then
        echo "${FUNCNAME[0]}: ${cmd} is '${file}' from PATH" >&2
        local file_result="$(file -L ${file})"
        local file_result_first_line="${file_result%%$'\n'*}"
        # Result is of the for '<name>: <information>'
        # and we need to remove name because it could contain the word 'text'
        # and less likely but still possible: ASCII or UTF-8.
        local without_filename="${file_result_fist_line#*:}"
        local open_file=y
        case "${without_filename}" in
            *ASCII*|*UTF-8*|*text*) ;;
            *) read -p "File '${file}' is not ASCII or UTF-8 text, still open? [y/n] > " open_file ;;
        esac
        if [[ "${open_file}" == y ]] ; then
            command vim ${file}
        fi
        return
    fi

    if ! shopt -q sourcepath ; then
        return 0
    fi

    echo "${FUNCNAME[0]}: Looking for sourceable file in PATH" >&2
    file="$(find -L $(echo $PATH | tr ':' ' ') -name "${cmd}" ! -perm -100 -type f -print -quit)"
    if [[ -n "${file}" ]] ; then
        echo "${FUNCNAME[0]}: ${cmd} is non-executable file '${file}' from PATH" >&2
        command vim ${file}
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
    for f in $(find -L ${PATH} -maxdepth 1 -name "${cur}*" ! -perm -100 -perm -600) ; do
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
open-shell-function(){
    (
        if [[ "$1" == "--help" ]] ; then
            echo "Usage:"
            echo ""
            echo "    ${FUNCNAME[0]} FUNCTION"
            echo ""
            echo "Open the file containing the definition of a shell function"
            echo "The builtin \`declare -F\` is used to obtain the location. It"
            echo "gives the path that was used to source the file containing the"
            echo "definition.  Therefore, if the file was sourced using a"
            echo "relative path, then we will be missing the PWD at the time of"
            echo "sourcing."
            return 0
        fi

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

        echo "vc: Opening '${file}' at line ${lineno}"
        command vim ${file} +${lineno}
    )
}

_open-shell-function(){
    COMPREPLY=( $(compgen -A function -- ${COMP_WORDS[COMP_CWORD}) )
}


whence(){

    local follow_link
    if [[ $1 == -r ]] ; then
        follow_link=true
        shift
    fi
    local -r cmd=$1

    if alias ${cmd} 2>/dev/null ; then
        return
    fi

    local reset_extdebug=$(shopt -p extdebug)
    shopt -s extdebug

    local func file info link realpath
    # Shell function
    if info=$(declare -F ${cmd}) ; then
        if [[ -n ${follow_link} ]] ; then
            if ! file=$(echo ${info} | cut -d ' ' -f 3) ; then
                echo "Could not extract file from declare -F output" >&2
            fi
            realpath=" ~ $(realpath ${file})"
        fi
        echo "${info}${realpath}"
        return
    fi

    # File from PATH
    if file=$(command which ${cmd} 2>/dev/null) ; then
        : good
    elif file="$(find -L $(echo $PATH | tr ':' ' ') -mindepth 1 -maxdepth 1 -name "${cmd}" ! -perm -100 -type f)" ; then
        : good
    else
        return 1
    fi

    if [[ -n ${follow_link} ]] ; then
        realpath=" ~ $(realpath ${file})"
    fi
    echo "${file}${realpath}"
    ${reset_extdebug}
}

complete -F _vc vc whence
complete -F _open-shell-function open-shell-function

