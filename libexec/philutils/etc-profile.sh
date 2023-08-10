#
# p.use-profile runs 'bash --init-file <THIS FILE>' which does three main things:
# 1. This file has the contents of /etc/profile.sh for two reasons
#    a) The '--init-file' flag causes it to not be sourced, so its contents are
#       reproduced here.
#    b) The original /etc/profile sets the USER and LOGNAME variables using the
#       'id' command which lessens the illusion of being the other user.  When
#       troubleshooting another user's profile, it is important that USER be the
#       username of the other user because they may have '$USER' somewhere in
#       what we are troubleshooting.
# 2. Load extra tools from to help with troubleshooting
#    a) vc: Find and open either a script from PATH or the file defining a shell
#       function
#    b) whence: A supercharged 'which' command that either returns the full path
#       of a command in $PATH (what 'which' does) or the path and line number
#       where a shell function is defined.
#    c) TODO: Add a function to dump the other user's environment to a file
#       like p.env(){ env -0 | sort -z | tr '\0' '\n' ; }
# 3. Source the other user's ~/.profile.  Because we use the --init-file flag
#    get full control of the startup, the other user's ~/.profile does not get
#    sourced automatically even if we add '-l' or '--login'.  The '--login' flag
#    is still given to the BASH command but that is only so that $- will contain
#    the letter 'l'
#

pathmunge () {
    case ":${PATH}:" in
        *:"$1":*)
            ;;
        *)
            if [ "$2" = "after" ] ; then
                PATH=$PATH:$1
            else
                PATH=$1:$PATH
            fi
    esac
}

#
# Part that resets the USER and LOGNAME variables based on values returned
# by the `id` command
#
if [ -x /usr/bin/id ]; then
    # if [ -z "$EUID" ]; then
    #     # ksh workaround
    #     EUID=`/usr/bin/id -u`
    #     UID=`/usr/bin/id -ru`
    # fi
    ORIGINAL_USER="`/usr/bin/id -un`"
    ORIGINAL_LOGNAME=$ORIGINAL_USER
    ORIGINAL_HOME="$(eval echo ~$ORIGINAL_USER)"
    # MAIL="/var/spool/mail/$USER"
fi

# Path manipulation
if [ "$EUID" = "0" ]; then
    pathmunge /usr/sbin
    pathmunge /usr/local/sbin
else
    pathmunge /usr/local/sbin after
    pathmunge /usr/sbin after
fi

HOSTNAME=`/usr/bin/hostname 2>/dev/null`
HISTFILE=$(eval echo ~${ORIGINAL_USER}/.alternate_history)
HISTSIZE=1000
if [ "$HISTCONTROL" = "ignorespace" ] ; then
    export HISTCONTROL=ignoreboth
else
    export HISTCONTROL=ignoredups
fi

export PATH USER LOGNAME MAIL HOSTNAME HISTSIZE HISTCONTROL

# By default, we want umask to get set. This sets it for login shell
# Current threshold for system reserved uid/gids is 200
# You could check uidgid reservation validity in
# /usr/share/doc/setup-*/uidgid file
if [ $UID -gt 199 ] && [ "`/usr/bin/id -gn`" = "`/usr/bin/id -un`" ]; then
    umask 002
else
    umask 022
fi

for i in /etc/profile.d/*.sh /etc/profile.d/sh.local ; do
    if [ -r "$i" ]; then
        if [ "${-#*i}" != "$-" ]; then 
            . "$i"
        else
            . "$i" >/dev/null
        fi
    fi
done

unset i
unset -f pathmunge

if [ -n "${BASH_VERSION-}" ] ; then
        if [ -f /etc/bashrc ] ; then
                # Bash login shells run only /etc/profile
                # Bash non-login shells run only /etc/bashrc
                # Check for double sourcing is done in /etc/bashrc.
                . /etc/bashrc
       fi
fi


echo "$HOME/.profile"
if [[ -v USE_PROFILE_XTRACE ]] ; then
    export PS4='+ \033[35m[${BASH_SOURCE[0]}:${LINENO}]\033[0m '
    set -x
fi

package_dir="$(cd "$(dirname $0)/.." && pwd)"
if [[ -f "${package_dir}/etc/profile.d/vc.bash" ]] ; then
    source "${package_dir}/etc/profile.d/vc.bash"
fi
source $HOME/.profile
p.use-profile.adapt_ps1(){
    PS1="$(echo "$PS1" | sed 's/\\u/$USER/')"
}
if [[ -n "${PROMPT_COMMAND}" ]] ; then
    PROMPT_COMMAND="${PROMPT_COMMAND};p.use-profile.adapt_ps1"
else
    adapt_ps1
fi
# So that HOME shows up as `~` in prompt
cd $HOME
