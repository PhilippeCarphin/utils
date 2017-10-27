#!/bin/bash
repo_name=$1
repo_alias=$2

echo "Repo_name : $repo_name"
echo "repo_alias : $repo_alias"
if [[ "$repo_name" == "" ]] ; then
	echo "ERROR: Repo not specified"
	exit 1
fi
if [[ "$repo_alias" == "" ]] ; then
	echo "ERROR : Repo alias not specified"
	exit 1
fi

cd ~/Documents/GitHub
if [[ "$?" != 0 ]] ; then
	echo "Error : Directory ~/Documents/GitHub does not exist"
	exit 1
fi
if [[ "$?" != 0 ]] ; then
	echo "ERROR: Repo with name $repo_name already exists"
	exit 1
fi

make_alias="alias $repo_alias='cd ~/Documents/GitHub/$repo_name'"
echo "" >> ~/.github-aliases
echo "adding alias : $repo_alias='cd ~/Documents/GitHub/$repo_name' to .github-aliases"

make_dir="mkdir $repo_name"
eval $make_dir
echo $make_dir

cd $repo_name


