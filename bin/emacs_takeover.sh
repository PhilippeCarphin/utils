#!/bin/bash
#
# subcommands
#
#     takeover : Save the current links and replace with links to pwd
#
#     restore  : Restore the saved links
#
# Takes a list of links
#
# For each link:
#     base=$(basename link)
#     backup_link_in_pwd
#     replace link with link to $PWD/base
#
# For each link:
#     if it didn't exist before, deleteit
#     otherwise replace it with it's backed up value
#
# list elements must be links.  Your files should not end with '.restore' or
# '.delete'.

files="$HOME/.emacs $HOME/.emacs.d $HOME/.spacemacs $HOME/.spacemacs.d"

################################################################################
# Make the current directory's emacs files the active ones and save the
# emacs links.
################################################################################
takeover(){
    if [ -e $token ] ; then
       echo "Already taken over"
       exit 1
    fi

    for f in $files ; do
        maybe_take $f
        maybe_link $f
    done

    touch $token
}

################################################################################
# Restore from the saved emacs links in the current directory.
################################################################################
restore(){
    for f in $files ; do
        maybe_restore $f
    done
    rm $token
}
################################################################################
# Save is either saving a copy of the link or remembering that there was nothing
# there
################################################################################
maybe_take(){
    local src=$1

    if ! [ -e $src ] ; then
        echo "$(tput setaf 5)REMEMBERING that there was no $src file by touching $(basename $src).delete$(tput sgr 0)"
        touch $(basename $src).delete
    else
        echo "$(tput setaf 2)SAVING $src as $(basename $src).restore$(tput sgr 0)"
        mv $src $(basename $src).restore
    fi
}
################################################################################
# Restore by either deleting or squashing with the saved file
################################################################################
maybe_restore(){
    local to_restore=$(basename $1)
    local restoration_file=$(find . -name "$to_restore.restore" -o -name "$to_restore.delete" | tail -1)
    local dst=$1

    if [ -z $restoration_file ] || ! [ -e $restoration_file ] ; then
        return 0
    fi

    if [[ $restoration_file == *restore ]] ; then
        echo "$(tput setaf 3)RESTORING $dst from $restoration_file$(tput sgr 0)"
        mv $restoration_file $dst
    elif [[ $restoration_file == *delete ]] ; then
        rm $restoration_file
        if [ -L $dst ] ; then
            echo "$(tput setaf 1)DELETING link $dst$(tput sgr 0)"
            rm -f $dst
        fi
    fi
}

################################################################################
# Create a link for the file if the target exitst in pwd
################################################################################
maybe_link(){
    local link_name=$1
    local base=$(basename $1)
    base=${base##.}
    local target=$this_dir/$base

    if [ -e $target ] ; then
       echo "$(tput setaf 4)LINKING $link_name --> $target$(tput sgr 0)"
       ln -s $target $link_name
    fi
}

################################################################################
# Execution
################################################################################

for f in $files ; do
    if [ -e $f ] && ! [ -L $f ] ; then
        echo "ERROR : file $f exists and is not a link"
        exit 1
    fi
done

this_dir=$PWD
token=ACTIVE

case $1 in
    takeover)
        takeover
        ;;
    restore)
        restore
        ;;
esac
