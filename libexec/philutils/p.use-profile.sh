#!/bin/bash


_p.use-profile-usage(){
    echo "Usage : $0 [OPTIONS] USERNAME

    Pretend to be user USERNAME by creating fresh
    bare environment and setting cd-ing to user's home
    setting HOME=~\$USERNAME and starting 'bash -l'

    Set USE_PROFILE_XTRACE to non-empty value to have xtrace turned on"

    if [[ $1 == 'long' ]] ; then
    echo "
    Note on DISPLAY: X11 authentication looks in your
    home for stuff, so after loading the user's
    environment, set HOME=\$YOUR_REAL_HOME for X11
    things to work.

    See below for an attempt to do that automatically.
    It prevents us from getting the user's prompt string
    and who knows what else.  Bottom line, if you need
    X11 stuff, set HOME=\$YOUR_REAL_HOME manually"
    else
    echo "Use --help for more info"
    fi
}

p.base-env(){
    ssh localhost env | grep -v '^SSH\|^PWD\|^LANG=\|^LC_\|^LOGNAME=\|^USER=\|^HOME='
    echo "SSH_CONNECTION=\"$SSH_CONNECTION\""
    echo "SSH_CLIENT=\"$SSH_CLIENT\""
    if [[ -v USE_PROFILE_XTRACE ]] ; then
        echo "USE_PROFILE_XTRACE=\"$USE_PROFILE_XTRACE\""
    fi
    echo "TERM=$TERM"
    if [[ -v DISPLAY ]] ; then
        echo "DISPLAY=$DISPLAY"
    fi
}

escape_symbols(){
    #
    # It looks like my ssh command for getting the base_env sources my BASHRC
    #
    sed \
        -e 's|(|\\(|' \
        -e 's|)|\\)|'
}


p.use-profile(){
    local adapt_ps1=true
    local username
    local -a posargs
    while (($# > 0)) ; do
        case "$1" in
            --help|-h) _p.use-profile-usage ; return 0 ;;
            "") _p.use-profile-usage "$@" ; return 1 ;;
            -d|-x|--debug) dbg=-x ; shift ;;
            --no-adapt-ps1) adapt_ps1=false ; shift ;;
            --) posargs=( "$@" ) ; break ;;
            *) posargs+=( "$1" ) ; shift ;;
        esac
    done
    case ${#posargs[@]} in
        0) echo "ERROR: A username is required" >&2 ; return 1 ;;
        1) username="${posargs[0]}" ;;
        *) echo "ERROR: More than one positional arguments : ${posargs*}" >&2 ; return 1 ;;
    esac

    profile="$(cd -P $(dirname $0)/../libexec/philutils/ && pwd)/etc-profile.sh"

    # Doing `userdir="$(eval echo ~$username)" is the simplest way to go but we
    # are doing eval with user supplied input.  For example, replacing 'tree'
    # in `p.use-profile "; tree"`, with something worse, we would have a bad
    # day.
    #
    # Looking for a way to specifically trigger just Tilde Expansion led me to
    # this https://stackoverflow.com/a/29310477 which shows that a) BASH does
    # not seem to provide a way to tilde-expand a variable's value and that
    # tilde expansion has a couple more features than expanding to a user's
    # home directory.  Since in my case, I only care about getting the home dir
    # of a user, there is a command that does that which I found out about in
    # that answer.
    local userdir
    if ! IFS=":" read _ _ _ _ _ userdir _ < <(getent passwd "${username}") ; then
        echo "ERROR: Could not get home dir of user '${username}'" >&2
        return 1
    fi

    if ! cd $userdir 2>/dev/null ; then
        echo "${FUNCNAME[0]} : ERROR : Could not cd to '$userdir'"
        return 1
    fi

    local old_ifs=${IFS}
    local IFS=$'\n'
    base_env=( $(p.base-env 2>/dev/null | escape_symbols ) )
    if [[ -v dbg ]] ; then
        base_env+=( "PS4=$PS4" )
    fi
    if [[ -v XAUTHORITY ]] ; then
        base_env+=( "XAUTHORITY=${XAUTHORITY}" )
    fi
    IFS=${old_ifs}
    if ${adapt_ps1} ; then
        base_env+=( "USE_PROFILE_ADAPT_PS1=true" )
    fi

    if [[ -v DISPLAY ]] ; then
        echo "Set HOME back to your own user home dir for X11 display stuff to work" >&2
    fi

    echo "${FUNCNAME[0]}: BASE ENVIRONMENT"
    for v in "${base_env[@]}" ; do
        echo "    '${v}'"
    done

    env -i "${base_env[@]}" \
        LOGNAME=${username} \
        HOME=$userdir \
        ORIGINAL_USER=${USER} \
        ORIGINAL_HOME=${HOME} \
        ORIGINAL_LOGNAME=${LOGNAME} \
        bash --init-file ${profile} ${dbg}
}

p.use-profile $@


# NOTES ABOUT DISPLAY
#
# When in not through an SSH connection, the variable XAUTHORITY is sufficient
# for X11 stuff to work even if $HOME is another user's HOME.
#
# However when through an SSH connection, X11 uses HOME (presumably to look at
# the file ~/.Xauthority) for authentication which is why it doesn't work if
# HOME is some other user's HOME.  In that case setting HOME back to your own
# HOME will make X11 stuff work but slightly ruins the illusion.
