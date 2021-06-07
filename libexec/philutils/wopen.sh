#!/bin/bash

url=$1
file=$(basename $url)

wget $url

if [[ $(uname) == Darwin ]] ; then
    open $file
else
    xdg-open $file
fi
