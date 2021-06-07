#!/bin/bash
cmd='stow -v -t $HOME/.local/bin -d . -R bin'

echo "Execute '$cmd'? Press any key (C-c to abort)"
read

eval $cmd
