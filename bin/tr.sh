#!/bin/bash
levels=2
n_lines=10
cmd=tree
while [[ $# -gt 0 ]]
do
    option="$1"
	optarg="$2"
    case $option in
        -L|--levels)
			levels="$optarg"
			shift
			;;
		-l|--lines)
			n_lines="$optarg"
			shift
			;;
		-c|--cmd)
			cmd="$optarg"
			shift
			;;
        *)
            echo "unknown option: $option"
            exit
			;;
    esac
shift
done

while true
do
	phil_pwd=$(<~/.philpwd)
	d=$(basename $phil_pwd)
	n_lines=$(($(tput lines) - 3))
	clear
	echo "contenu de $d"
	echo "contenu de $d" | sed 's/./=/g'
	if [[ $cmd == "ls" ]] ; then
		ls --color $phil_pwd
	else
		tree -L $levels $phil_pwd | tail -n +2 | grep '^[^0-9]' | sed 's/^/  /' | head -n $n_lines
	fi
	sleep 0.5
done
