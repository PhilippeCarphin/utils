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
#   ${COMP_WORDS[1]} to see if it contains a ':'
# - If ~/.inputrc contains 'set colored-stats on' or 'set visible-stats on', they
#   will have no effect on how completions are displayed for paths starting
#   with a ':'.  I haven't figured out how to 

################################################################################
# Change directory relative to the root of the git repo.  Paths must start with
# ':' to follow the use of the ':' magic pathspec in git.
################################################################################
__git_cd(){
    local -r colon_path="${1}"


    if [[ "${colon_path}" != :* ]] ; then
        printf "${FUNCNAME[0]}: \033[1;31mERROR\033[0m: Path must begin with a ':'\n"
        return 1
    fi

    local -r repo_subdir="${colon_path##:}"
    local repo_dir
    if ! repo_dir="$(git rev-parse --show-toplevel)" ; then
        printf "${FUNCNAME[0]}: \033[1;31mERROR\033[0m: $(pwd) see above\n"
        return 1
    fi

    local dir=${repo_dir}${repo_subdir}
    if ! builtin cd "$dir"; then
        printf "${FUNCNAME[0]}: \033[1;31mERROR\033[0m: ${colon_path} see above\n"
        return 1
    fi

    if [[ -n "${GIT_CD_VERBOSE:-}" ]] ; then
        printf "\033[33mcd ${dir}\033[0m\n"
    fi
}

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
__complete_git_colon_paths(){
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

    if [[ "${cur}" != ':' ]] && [[ "${prev}" != : ]] ; then
        _filedir ${filedir_opt}
        if [[ -n ${BASH_XTRACEFD} ]] ; then
            echo "COMPREPLY: (${COMPREPLY[@]})" >&${BASH_XTRACEFD}
        fi

        # filedir without the -d option can give duplicates
        # and I want to be able to do 'vim somedir/empty' and
        # have a space added to indicate to me that the directory
        # is empty, completion cannot continue, hence this
        # this line to remove duplicates.
        COMPREPLY=($(echo ${COMPREPLY[@]} | tr ' ' '\n' | sort | uniq))
        # The "Completion cannot continue" is a special case.
        # ${filedir_opt} == -d: then we do the following
        # ${filedir_opt} == "": then if COMPRELPY has only one element
        #      that's because it is a file, otherwise if there is only
        #      one possibility and it is a directory, COMPREPLY will
        #      have twice the same element COMPREPLY[0] == COMPREPLY[1]
        #      and if that element is an empty directory, then we
        #      can turn off 'compopt -o filenames' and force a space
        #      to be added that way which could be faster than removing
        #      duplicates from COMPREPLY
        #      NO, I'm going to leave it like this.  How many files
        #      would we need to have for it to make a significant time
        #      difference?  I did a little test with a COMPREPLY having
        #      200k elements and for that ridiculous amount the time is
        #      around 0.6 seconds.  For 30k, it's about 0.08 seconds
        #      So I'm keeping the duplicate removal because it is easier
        #      to think about 
        if ((${#COMPREPLY[@]} == 1)) ; then
            # Do this eval to resolve any ~/ or ~USER/
            local one_candidate=$(eval echo ${COMPREPLY[0]})
            if [[ -d ${one_candidate} ]] ; then
                COMPREPLY[0]+=/;
                one_candidate+=/
            fi
            local find_opt
            if [[ ${compgen_opt} == "-d" ]] ; then
                find_opt=(-type d)
            fi
            if [[ "$(find ${one_candidate} -maxdepth 1 "${find_opt[@]}")" == ${one_candidate} ]] ; then
                compopt +o filenames
            fi
        fi;
    else

        if ! git_repo="$(git rev-parse --show-toplevel 2>/dev/null)" ; then
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

        local i=0

        # Could be replaced with 
        # COMPREPLY=( $(compgen <same> | sed "s|^${git_repo}||") )
        # but then I couldn't use ${full_path} in the subsequent IF,
        # I would just have to use "${git_repo}/${COMPREPLY[0]}"
        # which feels like it would look more legit.
        for full_path in $(compgen ${compgen_opt} -- ${git_repo}${cur}) ; do
            relative_path="${full_path##${git_repo}}"
            COMPREPLY[i++]="${relative_path}"
        done

        # Only one completion candidate and it is a directory
        # -> Emulate behavior of 'cd' by adding a slash and telling
        #    readline to not add a space at the end of the word.
        if ((${#COMPREPLY[@]} == 1)) ; then
            if [[ -d ${git_repo}${COMPREPLY[0]} ]] ; then
                COMPREPLY[0]+=/;
            fi
            local find_opt
            if [[ ${compgen_opt} == "-d" ]] ; then
                find_opt=(-type d)
            fi
            if ! [[ $(find ${full_path} -maxdepth 1 "${find_opt[@]}") == ${full_path} ]] ; then
                compopt -o nospace
            fi
        fi;
    fi
}


__complete_git_colon_dirs(){
    __complete_git_colon_paths -d
}

__resolve_colon_path(){
    local repo_dir
    if ! repo_dir=$(git rev-parse --show-toplevel) ; then
        echo "${FUNCNAME[0]} : ERROR See above" >&2
        return 1
    fi

    if [[ ${1} != :* ]] ; then
        echo "${FUNCNAME[0]} : Path must start with ':'" >&2
        return 1
    fi

    echo "${repo_dir}${1#:}"
}

#
# Only works for commands.  If you want to do it for a shell function
# you can edit the code of the shell function yourself if it is one
# of your shell functions.  Otherwise, I'm afraid I can't do anything
# for you.
#
wrap_command_colon_paths(){
    local cmd="${1}"
    shift

    declare -a args
    local i=0
    local arg
    for arg in "$@" ; do
        local new_arg
        case "${arg}" in
            :*)
                if ! new_arg=$(__resolve_colon_path "${arg}") ; then
                    echo "${FUNCNAME[0]} ERROR see above"
                    return 1
                fi
                ;;
            *)
                new_arg="${arg}"
                ;;
        esac
        args[i++]="${new_arg}"
    done

    # if [[ -n GIT_COLONPATH_VERBOSE ]] ; then
    #     printf "command %s %s\n" "${cmd}" "${args[*]}"
    # fi
    ${cmd} "${args[@]}"
}

################################################################################
# Switching function that delegates to git_cd if the argument starts with ':'
# or to builtin cd otherwise.
################################################################################
__cd_or_git_cd(){
    local -r path_or_colon_path="${1}"
    case "${path_or_colon_path}" in
        :*) __git_cd "$@" ;;
        *) builtin cd "$@" ;;
    esac
}

################################################################################
# Switching function that delegates to _git_cd if completing a word that begins
# with ':' or to _cd (completion function for cd) otherwise.
################################################################################
_cd_or_git_cd(){
    case "${COMP_WORDS[1]}" in
        :*) __complete_git_colon_paths_dirs ;;
        *) _cd ;;
    esac
}

