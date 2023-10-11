# NOTE: It seems like compdef with alias works funny, the alias is resolved
# and compdef looks for like the command after the alias is resolved or
# so completion is done for the command that gets run by the alias
# which would be wrap_command_colon_paths which does not have completion
# so default takes over and therefore we get nothing when using ':/'.
#
#     $ alias cd='wrap_command_colon_paths cd'
#     $ compdef __complete_git_colon_paths cd
#     $ cd :/<TAB><TAB> >>> Nothing happens
#     $ compdef __complete_git_colon_paths wrap_command_colon_paths
#     $ cd :/<TAB><TAB> >>> We get completions
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
__complete_git_colon_paths(){
    local cur=${words[-1]}
    local compgen_opt=${1}
    local filedir_opt
    case ${1} in
        -f) ;; # OK
        -d) filedir_opt="-d" ;; # OK
        *) compgen_opt="-f" ;;
    esac

    if [[ "${cur}" != :* ]] ; then
        __complete_non_colon_path
    else
        __complete_true_colon_path
    fi
}

__complete_git_colon_dirs(){
    __complete_git_colon_paths -d
}

__resolve_git_colon_path(){
    local repo_dir
    if ! repo_dir=$(__get_super_repo_root) ; then
        echo "${funcstack[1]} : ERROR See above" >&2
        return 1
    fi

    if [[ ${1} != :* ]] ; then
        echo "${funcstack[1]} : Path must start with ':'" >&2
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

    local -a args
    local arg
    for arg in "$@" ; do
        local new_arg
        case "${arg}" in
            :*)
                if ! new_arg=$(__resolve_git_colon_path "${arg}") ; then
                    echo "${FUNCNAME[0]} ERROR see above"
                    return 1
                fi
                ;;
            *)
                new_arg="${arg}"
                ;;
        esac
        args+=("${new_arg}")
    done

    # if [[ -n GIT_COLONPATH_VERBOSE ]] ; then
    #     printf "command %s %s\n" "${cmd}" "${args[*]}"
    # fi
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
__complete_non_colon_path(){
    local cur=${words[-1]}
    if [[ -d ${cur} ]] && ! contains_directories ${cur} ]] ; then
        compadd -P '' -Q -f "${cur} "
        return
    fi
    _cd
}

function contains_directories(){
    # Expand tilde
    local dir=$(eval echo $1)
    ! [[ $(find ${dir} -maxdepth 1 -type d) == ${dir} ]]
}

__get_super_repo_root(){
    local super_repo_root
    super_repo_root=$(git rev-parse --show-superproject-working-tree --show-toplevel 2>/dev/null | head -n 1)
    echo "${super_repo_root}"
}

__complete_true_colon_path(){
    valid_candidates=()

    local git_repo
    echo "words=${words[@]}" >> ~/.log.txt
    if ! git_repo="$(git rev-parse --show-toplevel 2>/dev/null)" ; then
        return 1
    fi
    echo "git_repo=${git_repo}" >> ~/.log.txt

    local cur=${words[-1]}

    # Complete 'cd :' to 'cd :/'.  This is important since otherwise, we
    # risk getting candidates from the parent directory of the git repo:
    # If we are in /home/phc001/repo but /home/phc001/repo_alternate exists,
    # then without this, compgen -d /home/phc001/repo will give those two
    # directories.
    if [[ "${cur}" == : ]] ; then
        # valid_candidates=("/")
        compadd -f -S '' -Q ":/"
        return
    fi

    subdir=${cur#:} 
    echo "subdir=${subdir}" >> ~/.log.txt

    # Note: We ensure that ${cur} always starts with ':/' so we don't put one
    # between ${git_repo} and ${cur#:}.
    full_cur="${git_repo}${subdir}"
    echo "full_cur=${full_cur}" >> ~/.log.txt

    candidates=($(ls -d --color=never ${full_cur}*))
    # echo "candidates=${candidates[*]}" >> ~/.log.txt
    for full_path in "${candidates[@]}" ; do
        if ! [[ -d "${full_path}" ]] ; then
            continue
        fi
        relative_path="${full_path##${git_repo}}"
        valid_candidates+=("${relative_path}")
    done

    # Add slash if we have only one completion
    # Lifted from _cd and changed to just always append the slash if
    # there is only one completion candidate.
    if ((${#valid_candidates[@]} == 1)); then
        echo "single candidate: ${valid_candidates[1]}" >> ~/.log.txt
        if contains_directories "${git_repo}${valid_candidates[1]}" ; then
            compadd -Q -S '' ":${valid_candidates[1]}/"
        else
            compadd -Q -S '' ":${valid_candidates[1]}/ "
        fi
    else
        comps=()
        for c in "${valid_candidates[@]}" ; do
            comps+=(":${c}")
            # compadd -S '' -f -Q ":${c}"
        done
        compset -P '*/'
        compset -S '/*'
        comps=(${comps##:*/})
        comps=(${comps%%/*})
        compadd -S '' -Q -f -a comps

    fi;
}

compdef __complete_non_colon_path a

