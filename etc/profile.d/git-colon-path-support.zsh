# Tools for working with the magic pathspec ':' for git repos.
__complete_git_colon_dirs(){
    local cur="${words[-1]}"
    if [[ "${cur}" != :* ]] ; then
        __complete_non_colon_dirs
    else
        __complete_true_colon_paths dirs
    fi
}

__complete_git_colon_files(){
    local cur="${words[-1]}"
    if [[ "${cur}" != :* ]] ; then
        _files
    else
        __complete_true_colon_paths
    fi
}

__resolve_git_colon_path(){
    local repo_dir
    if ! repo_dir=$(__get_root_superproject) ; then
        echo "${funcstack[1]} : ERROR See above" >&2
        return 1
    fi

    if [[ ${1} != :* ]] ; then
        echo "${funcstack[1]} : Path must start with ':'" >&2
        return 1
    fi

    echo "${repo_dir}${1#:}"
}

__get_root_superproject()(
    while true ; do
        if ! superproject_root="$(git rev-parse --show-superproject-working-tree)" ; then
            return 1
        fi

        if [[ -z "${superproject_root}" ]] ; then
            git rev-parse --show-toplevel
            return 0
        fi

        cd ${superproject_root}
    done
)

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
    local new_arg
    for arg in "$@" ; do
        case "${arg}" in
            :*)
                if ! new_arg=$(__resolve_git_colon_path "${arg}") ; then
                    echo "${funcstack[1]} ERROR see above"
                    return 1
                fi
                args+=("${new_arg}")
                ;;
            *)
                args+=("${arg}")
                ;;
        esac
    done
    ${cmd} "${args[@]}"
}
# For alias purposes
function wrap_command_colon_dirs(){
    wrap_command_colon_paths "$@"
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
__complete_non_colon_dirs(){
    echo "${funcstack[1]} start" >> ~/.log.txt
    local cur=${words[-1]}
    local exp_cur=$(eval echo ${cur})  # Tilde expansion
    echo "${funcstack[1]} exp_cur=${exp_cur}" >> ~/.log.txt
    if [[ -d ${exp_cur} ]] && ! contains_directories ${exp_cur} ]] ; then
        compadd -P '' -Q -f "${cur} "
        return
    fi

    # Fix words and CURRENT for _cd.  Note the code of _cd has a comment
    # complete words[2].  It doesn't complete the last word, it completes
    # words[2] period.
    CURRENT=2
    words=(whatever "${cur}")
    _cd
}

function contains_directories(){
    # Expand tilde
    local dir=$(eval echo $1)
    ! [[ $(find -L ${dir} -maxdepth 1 -type d 2>/dev/null) == ${dir} ]]
}
function contains_anything(){
    # Expand tilde
    local dir=$(eval echo $1)
    ! [[ "$(ls --color=never $dir)" == "" ]]
}

__complete_true_colon_paths(){
    valid_candidates=()
    local git_repo
    if ! git_repo="$(git rev-parse --show-toplevel 2>/dev/null)" ; then
        return 1
    fi

    # CDPATH=${git_repo} _files -/ -P :/
    # return
    echo "git_repo=${git_repo}" >> ~/.log.txt

    local cur=${words[-1]}

    if [[ "${cur}" == : ]] ; then
        compadd -f -S '' -Q ":/"
        return
    fi

    subdir=${cur#:} 

    # Note: We ensure that ${cur} always starts with ':/' so we don't put one
    # between ${git_repo} and ${cur#:}.
    full_cur="${git_repo}${subdir}"

    candidates=($(ls -d --color=never ${full_cur}*))
    # echo "candidates=${candidates[*]}" >> ~/.log.txt
    for full_path in "${candidates[@]}" ; do
        if [[ "${1}" == dirs ]] && ! [[ -d "${full_path}" ]] ; then
            continue
        fi
        relative_path="${full_path##${git_repo}}"
        valid_candidates+=("${relative_path}")
    done

    # Either end completion by setting a single candidate containing a space
    # or continue the completion by adding a slash for directories.
    # Note that -f and -d apply to links as well
    if ((${#valid_candidates[@]} == 1)); then
        if [[ -f "${git_repo}${valid_candidates[1]}" ]]; then
            # Regular files always end completion
            compadd -Q -S '' ":${valid_candidates[1]} "
        elif [[ -d "${git_repo}${valid_candidates[1]}" ]] then
            # Directories end completion differently depending on whether
            # directory completion ($1 == dirs) was requested:
            if ( [[ "${1}" == dirs ]] &&
                  ! contains_directories ${git_repo}${valid_candidates}) \
               || ! contains_anything ${git_repo}${valid_candidates[1]} ; then
                compadd -Q -S '' ":${valid_candidates[1]}/ "
            else
                compadd -Q -S '' ":${valid_candidates[1]}/"
            fi
        fi
    else
        comps=()
        for c in "${valid_candidates[@]}" ; do
            echo "adding ${c}" >> ~/.log.txt
            comps+=(":${c}")
        done
        compset -P '*/'
        compset -S '/*'
        comps=(${comps##:*/})
        comps=(${comps%%/*})
        compadd -S '' -Q -f -a comps
    fi;
}

compdef __complete_git_colon_files wrap_command_colon_paths
compdef __complete_git_colon_dirs wrap_command_colon_dirs
