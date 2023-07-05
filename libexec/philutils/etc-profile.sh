#
# This file is /etc/profile for use by `p.use-profile`.  It is used as
# env -i <base env> USER=${username} LOGNAME=${username} HOME=${userdir} bash --init-file <this-file>
# and this file ends with `source $HOME/.profile` to simulate a login shell.
#
# This is done instead of `bash -l` because with `-l`, it is hardcoded to source
# the true /etc/profile which resets $USER and $LOGNAME to values determined
# with the `id` command which cannot be faked.
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
source $HOME/.profile
adapt_ps1(){
    PS1="$(echo "$PS1" | sed 's/\\u/$USER/')"
}
if [[ -n "${PROMPT_COMMAND}" ]] ; then
    PROMPT_COMMAND="${PROMPT_COMMAND};adapt_ps1"
else
    adapt_ps1
fi
# So that HOME shows up as `~` in prompt
cd $HOME
