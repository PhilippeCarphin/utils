#!/bin/bash
#
# This enhances the `cd` builtin to understand the ':' magic pathspec for
# git repos.  With git, paths beginning with ':' are understood to be
# relative to the root of the repository.
#
# It provides
# - git_cd which CD's to paths starting with ':' with ':' interpreted as the
#   root of the current git repository
# - _git_cd which provides completion for git_cd
# - cd which delegates to git_cd if the first argument starts with ':' or to
#   builtin cd otherwise.
# _ _cd_and_git_cd which delegates to one of _cd or _git_cd based on whether
#   or not the word to complete starts with ':'.
#
# BUGS:
# - There is no logic to support options.  So for example, 'cd -P :/' will not
#   delegate to git_cd simply because the switching functions look at ${1} and
#   ${COMP_WORDS[1]} to see if it contains a ':' # - If ~/.inputrc contains 'set colored-stats on' or 'set visible-stats on', they
#   will have no effect on how completions are displayed for paths starting
#   with a ':'.  I haven't figured out how to

################################################################################
# Complete paths starting with ':' starting from the root of the current git
# repository.
#
# Not that the default behavior is that ':' is part of COMP_WORDBREAKS so if
# the line is 'cmd :/asd_" with '_' being the cursor, then the words will be
# "cmd", ":", "/asd" so if the current argument on the command line starts
# with ":", we will see it by checking that [[ ${prev} == ":" ]], the only
# exception si "cmd :_" where [[ ${cur} == ":" ]].
#
# The function takes a first argument to change between completing only
# directories or any filename.
################################################################################
_gcps_complete_colon_paths(){
    local compgen_opt=${1}
    local filedir_opt
    case ${1} in
        -f) ;; # OK
        -d) filedir_opt="-d" ;; # OK
        *) compgen_opt="-f" ;;
    esac

    local IFS=$'\n'
    compopt -o filenames
    local cur prev words cword git_repo
    _init_completion || return;

    # Because of COMP_WORDBREAKS, this checks for a command line word that
    # begins with ':'.
    if [[ "${cur}" != ':' ]] && [[ "${prev}" != : ]] ; then
        _gcps_complete_non_colon_path
    else
        _gcps_complete_true_colon_path
    fi
}

_gcps_complete_cd(){
    compopt -o filenames
    local cur prev words cword git_repo
    _init_completion || return;
    local compgen_opt=-d
    local filedir_opt=-d

    # See note about COMP_WORDBREAKS
    if [[ "${cur}" != ':' ]] && [[ "${prev}" != : ]] ; then
        _cd
        # The _cd function doesn't care if it puts in the same directory twice
        # because people don't expect from 'cd' that it adds a space when
        # completion can no longer continue.  However I do care.  Note that
        # this loses array information
        COMPREPLY=($(echo "${COMPREPLY[*]}" | sort | uniq))
        _gcps_handle_single_candidate "" -d
    else
        _gcps_complete_true_colon_path -d
    fi
}

_gcps_complete_colon_dirs(){
    _gcps_complete_colon_paths -d
}

_gcps_get_root_superproject_2(){
    local current=${1}
    local superproject_root
    while true ; do
        if ! superproject_root="$(command cd "${current}" && command git rev-parse --show-superproject-working-tree)" ; then
            return 1
        fi

        if [[ -z "${superproject_root}" ]] ; then
            (cd ${current} && command git rev-parse --show-toplevel)
            return 0
        fi

        current="${superproject_root}"
    done
}

_gcps_get_root_superproject()(
    while true ; do
        if ! superproject_root="$(command git rev-parse --show-superproject-working-tree)" ; then
            return 1
        fi

        if [[ -z "${superproject_root}" ]] ; then
            command git rev-parse --show-toplevel
            return 0
        fi

        cd ${superproject_root}
    done
)


_gcps_resolve_git_colon_path(){
    local repo_dir
    if ! repo_dir=$(_gcps_get_root_superproject) ; then
        echo "${FUNCNAME[0]} : ERROR See above" >&2
        return 1
    fi

    if [[ ${1} != :* ]] ; then
        echo "${FUNCNAME[0]} : Path must start with ':'" >&2
        return 1
    fi

    echo "${repo_dir}${1#:}"
}

gcps_wrap_command_colon_paths(){
    local cmd="${1}"
    shift

    declare -a args
    local arg=()
    for arg in "$@" ; do
        local new_arg
        case "${arg}" in
            :*)
                if ! new_arg=$(_gcps_resolve_git_colon_path "${arg}") ; then
                    echo "${FUNCNAME[0]} ERROR see above"
                    return 1
                fi
                echo "'${arg}' -> '${new_arg}'" 1>&2
                ;;
            *)
                new_arg="${arg}"
                ;;
        esac
        args+=("${new_arg}")
    done

    ${cmd} "${args[@]}"
}

################################################################################
# Perform directory completion with an extra twist.  Normally, standard filename
# completion will add a space when there is only one candidate and it is not a
# directory because completion cannot continue at this point.  When completing
# only directories and we arrive a point where we only have one candidate and it
# does not contain any directories, we could also say that completion cannot
# continue and a space should be added.  This is not the case and this function
# is me trying really hard to make it happen.
################################################################################
_gcps_complete_non_colon_path(){
    _filedir ${filedir_opt}
    if [[ -n ${BASH_XTRACEFD} ]] ; then
        echo "COMPREPLY: (${COMPREPLY[@]})" >&${BASH_XTRACEFD}
    fi

    # filedir without the -d option can give duplicates
    # and I want to be able to do 'vim somedir/empty' and
    # have a space added to indicate to me that the directory
    # doesn't contain directories
    local IFS=$'\n'
    COMPREPLY=($(echo "${COMPREPLY[*]}" | sort | uniq))
    _gcps_handle_single_candidate "" "${compgen_opt}"
}


_gcps_complete_true_colon_path(){
    if ! git_repo="$(_gcps_get_root_superproject ${PWD} 2>/dev/null)" ; then
        return 1
    fi

    # Complete ':' to ':/' and on the next tab press ${prev} will be ":" and
    # ${cur} will be "/"
    if [[ "${cur}" == : ]] ; then
        COMPREPLY=("/")
        return
    fi

    if [[ "${cur}" != /* ]] ; then
        return
    fi

    local i=0 full_path relative_path
    for full_path in $(compgen ${compgen_opt} -- ${git_repo}${cur}) ; do
        relative_path="${full_path##${git_repo}}"
        COMPREPLY[i++]="${relative_path}"
    done
        COMPREPLY=($(echo "${COMPREPLY[*]}" | sort | uniq))

    _gcps_handle_single_candidate ${git_repo} ${compgen_opt}
}

_gcps_handle_single_candidate(){
    local prefix=${1}
    local compgen_opt=${2}
    if ((${#COMPREPLY[@]} == 1)) ; then
        # Eval echo is to resolve anything that starts with '~'
        local only_candidate="${prefix:+${prefix}/}${COMPREPLY[0]}"
        __expand_tilde_by_ref only_candidate
        if [[ -f ${COMPREPLY[0]} ]] ; then
            compopt +o nospace
            compopt -o filenames
            return
        fi

        declare -p COMPREPLY >> ~/.log.txt
        if [[ -d ${only_candidate} ]] ; then
            COMPREPLY[0]+=/;
            only_candidate+=/
        fi
        local find_opt
        if [[ ${compgen_opt} == "-d" ]] ; then
            find_opt=(-type d)
        fi

        local search_dir=${only_candidate}

        #
        # Determine directory to search to decide if completion should continue
        # or not.  Note: _gcps_complete_cd delegates to _cd to produce
        # candidates which handles CDPATH so this is the only place where it
        # needs to be handled.
        #
        if ! [[ -d ${only_candidate} ]] ; then
            local OIFS=$IFS ; IFS=:
            for d in ${CDPATH} ; do
                if [[ -d ${d}/${only_candidate} ]] ; then
                    search_dir=${d}/${only_candidate}
                    break
                fi
            done
            IFS=${OIFS}
        fi

        # Note slash is to search content in case ${search_dir} is a link to a
        # directory.  Using 'find -L ${search_dir}' has the same effect except
        # that when find comes upon a filesystem loop, it prints that to stderr
        # and whenever possible, I don't want to do 2>/dev/null because I don't
        # want to miss future error messages.
        local sub=$(find ${search_dir}/ -mindepth 1 -maxdepth 1 "${find_opt[@]}" -printf .)
        if (( ${#sub} == 1)); then
            compopt +o filenames
        else
            compopt -o nospace
        fi
    elif ((${#COMPREPLY[@]} == 0)) ; then
        #
        # Add a space to end completion when ${cur} has a trailing slash
        # but does not contain anything that would allow completion to continue.
        #
        # If we have for example 'cd :/etc/profile.d/_' then because profile.d
        # contains no directories, then COMPREPLY will be empty.  This ensures
        # that a space is added 'cd :/etc/profile.d/ _'
        #
        if [[ -e "${git_repo}${cur}" ]] ; then
            COMPREPLY=(${cur})
            compopt +o nospace
            compopt +o filenames
        fi
    fi
}
