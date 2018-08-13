#!/bin/bash
#
cmd=$(basename $0)
# link_array=(" $HOME/.local/man/man1/link-pwd.1   man/man1/man_link-pwd.man" \
# "$HOME/.local/man/man1/link-pwd.1   man/man1/man_link-pwd.man")
################################################################################
# Save is either saving a copy of the link or remembering that there was nothing
# there
################################################################################
save_target(){
    local target=$1

    if [ -e $target ] ; then
        echo "$(tput setaf 2)SAVING $target as $(basename $target).restore$(tput sgr 0)"
        if $just_print ; then
           return
        fi
        mv $target $(basename $target).restore
    fi
}

################################################################################
# Restore by either deleting or squashing with the saved file
################################################################################
restore_target(){
    local target=$1
    local base_target=$(basename $target)
    local restore_file=$base_target.restore

    if [ -e $restore_file ] ; then
        echo "$(tput setaf 3)RESTORING $target from $restore_file$(tput sgr 0)"
        # Note that the -T option doesn't work on OSX's mv command so I have to
        # remove the link first otherwise, it might move $restore_file
        # into the directory pointed to by $target
        if $just_print ; then
           return
        fi
        rm -f $target
        mv $restore_file $target
    elif [ -L $target ] ; then
        echo "$(tput setaf 1)DELETING link $target$(tput sgr 0)"
        if $just_print ; then
           return
        fi
        rm -f $target
    elif [ -e $target ] ; then
        echo "$(tput setaf 1)[[ CANT HAPPEN ]]Target $target exists and is not a link$(tput sgr 0)"
        if $just_print ; then
           return
        fi
    fi
}

################################################################################
# Delete restore files in PWD
################################################################################
delete_restore_files()
{
    restore_files=$(find . -name '.*.restore' -o -name '*.restore')

    echo "$(tput setaf 1)Deleting restore files"
    echo "$restore_files$(tput sgr 0)"
    if $just_print ; then
        return
    fi
    rm -f *.restore .*.restore
}

################################################################################
# Create a link for the file if the target exitst in pwd
################################################################################
maybe_link(){
    local target=$1
    local link_name=$2

    if [ -e $target ] ; then
        echo "$(tput setaf 4)LINKING $link_name --> $target$(tput sgr 0)"
        if $just_print ; then
            return
        fi
        ln -s $target $link_name
    fi
}

################################################################################
# Create a link for the file if the target exitst in pwd
################################################################################
unlink_target(){
    local target=$1

    if [ -e $target ] && ! [ -L $target ] ; then
        echo "$cmd : ERROR : unlink_target : target=$target exits and is not a link"
        exit 1
    fi

    if [ -e $target ] ; then
        if $just_print ; then
           return
        fi
        echo "$(tput setaf 1)DELETING link $target$(tput sgr 0)"
        rm -f $target
    else
        echo "$(tput setaf 2)"
    fi
}

################################################################################
# Backs up /target/ in PWD and creates a link to /my_file/ in place of /target/
# with variations depending on the existence of /target/ and /my_file/
################################################################################
save_and_link(){
    local target=$1
    local my_file=$2
    save_target $target $my_file
    maybe_link $my_file $target
}

################################################################################
# Prints a bunch of info on the concerned files
################################################################################
status()
{
    local target=$1
    local my_file=$2
    local base_target=$(basename $target)
    local restore_file="$base_target.restore"

    if ! [ -z $restore_file ] && [ -e $restore_file ] ; then
        echo "$(tput setaf 3)Restore $(ls -l $restore_file | tr -s ' ' | cut -d ' ' -f 9,10,11)$(tput sgr 0)"
    elif ! [ -e $restore_file ] && ! [ -e $target ]; then
        echo "$(tput setaf 208)No Restore file for target $target.$(tput sgr 0)"
    elif [ -L $target ] ; then
        echo "$(tput setaf 208)Target $target exists but no Restore file.  Restore will delete it$(tput sgr 0)"
    fi

    if [ -e $target ] && [ -L $target ] ; then
        echo "$(tput setaf 4)Target $(ls -l $target | tr -s ' ' | cut -d ' ' -f 9,10,11)$(tput sgr 0)"
    elif [ -e $target ] ; then
        echo "$(tput setaf 1)Target $(ls -l $target | tr -s ' ' | cut -d ' ' -f 9,10,11) exists and is not a link$(tput sgr 0)"
    else
        echo "$(tput setaf 208)Target $target does not exist$(tput sgr 0)"
    fi

    if [ -e $my_file ] ; then
        if [ -d $my_file ] ; then
           echo "$(tput setaf 2)My File : Directory $my_file$(tput sgr 0)"
        else
            echo "$(tput setaf 2)My File : $(ls -l $my_file | tr -s ' ' | cut -d ' ' -f 9,10,11)$(tput sgr 0)"
        fi
    else
        echo "Myfile $my_file does not exist"
    fi
}

this_dir=$PWD



################################################################################
# Functions used to validate lines
################################################################################
error_restore(){
    echo "$cmd : ERROR : Cannot $1 because there are restore files present"
    echo "$cmd : ERROR : Check it out and run 'link-pwd forget' to clear restore files"
}

exists_restore_files()
{
    ls -a | grep '.\.restore' > /dev/null
}

is_group(){
    local line=$1
    echo $line | grep '\[[a-zA-Z0-9]\+\]' >/dev/null
}

get_group()
{
    local line=$1
    line=${line%%']'}
    line=${line##'['}
    echo $line
}

valid_line()
{
    local c1=$1
    local c2=$2
    local c3=$3
    if echo $c1 '^#' > /dev/null ; then
        return 0
    fi

    if is_group $c1 ; then
        if echo $c1 | grep '\[[^a-zA-Z0-9]\+\]' >/dev/null ; then
            echo "Forbidden characters in group name"
            return 1
        fi
        if ! [ -z $c2 ] ; then
            echo "Extra text after group : $2"
            return 1
        fi
    else
        if echo $c1 | grep '[\[\]]\+]' >/dev/null ; then
            echo "The chars '[' and ']' are not allowed in paths"
            return 1
        fi
        if ! [ -z $c3 ] ; then
            echo "Too many words on line"
            return 1
        fi
    fi
    return 0
}

################################################################################
# Execution
################################################################################
#
##################### Action based on presence of token file ###################

################################################################################
# Option parsing
################################################################################
action=status
link_file=Linkfile
just_print=false
status_after=false
initial_command_line="$@"
while [[ $# -gt 0 ]]
do
    option="$1"
    optarg="$2"
    case $option in
        -s|--status-after)
            status_after=true
            ;;
        -jp|--just-print)
            just_print=true
            ;;
        -g|--group)
            if [ -z $optarg ] ; then
                echo "ERROR --group optarg empty"
                exit 1
            fi
            group_to_link=$optarg
            shift
            ;;
        -f|--file)
            if [ -z $optarg ] ; then
                echo "ERROR --file optarg empty"
                exit 1
            fi
            link_file=$optarg
            shift
            ;;
        forget)
            delete_restore_files
            exit 0
            ;;
        unlink)
            if ! exists_restore_files ; then
                action=save_target
            else
                error_restore unlink
                action=status
            fi
            ;;
        link)
            if ! exists_restore_files ; then
                action=save_and_link
            else
                error_restore link
                action=status
            fi
            ;;
        restore)
            action=restore_target
            ;;
        status)
            action=status
            ;;
        *)
            echo "Unknown subcommand $subcommand"
            ;;
    esac
    shift
done

################################################################################
# Validation of linkfile and its content
# Must be in PWD just to avoid complications
# Must have all valid lines as defined by the function
# All targets must be links or not exist
################################################################################
link_file=$PWD/$(basename $link_file)
if ! [ -e $link_file ] ; then
    echo "$cmd : ERROR : No \$PWD/$(basename $link_file)"
    echo "Note that this tool wants you to be in the same directory as the linkfile even if you specify it on the command line"
    exit 1
fi
if [[ "$1" != status ]] ; then
    i=1
    while read col1 col2 extra ; do
        if ! valid_line $col1 $col2 $extra ; then
            echo "INVALID LINE in Linkfile : $i"
        fi
        if [[ "$col1" != \#* ]] ; then
            the_target=$(eval echo $col1)
            if [ -e $the_target ] && ! [ -L $the_target ] ; then
                echo "$cmd : ERROR : Linkfile line $i : the_target=$col1 exists and is not a link"
                errors=true
            fi
        fi
        i=$(($i + 1))
    done < $link_file

    if [[ $errors == true ]] ; then
        exit
    fi
fi

################################################################################
# Running the specified command for all the lines of Linkfile with various
# conditions for skipping lines
# - Comment
# - group name : change group
# - not the right group
################################################################################
if [ -e $Linkfile ] ; then
    while read column_1 column_2 extra ; do

        if [[ "$column_1" = \#* ]] ; then
            continue
        fi

        if is_group $column_1 ; then
            current_group=$(get_group $column_1)
            continue
        fi

        if [[ $group_to_link != $current_group ]] ; then
            continue
        fi

        the_target=$(eval echo $column_1)
        the_my_file=$this_dir/$(eval echo $column_2)
        ! [ -z $action ] && $action $the_target $the_my_file

    done < $link_file
elif ! [ -z "$link_array" ] ; then
    exit 0
    if [[ $this_dir == $PWD ]] ; then
        for l in "${link_array[@]}" ; do
            the_target=$(echo $l | tr -s ' ' | cut -d ' ' -f 1)
            the_my_file=$this_dir/$(echo $l | tr -s ' ' | cut -d ' ' -f 2)
            ! [ -z $action ] && $action $the_target $the_my_file
        done
    else
        echo "$0 : ERROR : The script needs to be called from the directory where it is to be used without a Linkfile"
        exit 1
    fi
else
    echo "$cmd : ERROR :No links array in script and no Linkfile in pwd"
fi
if $status_after ; then
    echo "===== status after link-pwd $initial_command_line"
    link-pwd status
fi


