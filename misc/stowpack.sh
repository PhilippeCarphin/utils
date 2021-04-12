#!/bin/bash
cmd='stow -v -t $HOME/.local -d . -R $1'

echo "Execute '$cmd'? Press any key (C-c to abort)"
read

eval $cmd
