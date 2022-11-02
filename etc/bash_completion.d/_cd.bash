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
################################################################################
_git_cd(){
    local IFS=$'\n'

    compopt -o filenames
    local cur prev words cword git_repo
    _init_completion || return;

    if ! git_repo="$(git rev-parse --show-toplevel 2>/dev/null)" ; then
        return 1
    fi

    # Complete 'cd :' to 'cd :/'.  This is important since otherwise, we
    # risk getting candidates from the parent directory of the git repo:
    # If we are in /home/phc001/repo but /home/phc001/repo_alternate exists,
    # then without this, compgen -d /home/phc001/repo will give those two
    # directories.
    if [[ "${cur}" == : ]] ; then
        COMPREPLY=("/")
        return
    fi

    # Because COMP_WORDBREAKS contains ':', when the command line is 'cd :',
    # the words array is ('cd' ':') in which case we do the above completion.
    # In every other case such as 'cd :/a', the words array is ('cd' ':' '/a')
    # If we wanted to keep the words as they are on the command line without
    # separating on colons, then we need to do as in _complete_git_cd_with_colons
    # and use __rassemble_comp_words_by_ref and __ltrim_colon_completions
    if [[ "${prev}" != : ]] ; then
        return
    fi

    # Note: We ensure that ${cur} always starts with ':/' so we don't put one
    # between ${git_repo} and ${cur#:}.
    full_cur="${git_repo}${cur}"

    local i=0
    for full_path in $(compgen -d -- ${git_repo}${cur}) ; do
        relative_path="${full_path##${git_repo}}"
        COMPREPLY[i++]="${relative_path}"
    done

    # Add slash if we have only one completion
    # Lifted from _cd and changed to just always append the slash if
    # there is only one completion candidate.
    if ((${#COMPREPLY[@]} == 1)); then
        COMPREPLY[0]+=/;
    fi;
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
        :*) _git_cd ;;
        *) _cd ;;
    esac
}

alias cd=__cd_or_git_cd
complete -o nospace -F _git_cd git_cd
complete -o nospace -F _cd_or_git_cd cd
