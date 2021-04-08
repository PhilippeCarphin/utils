#!/usr/bin/env python3
import argparse
import subprocess

p = argparse.ArgumentParser(description="Add push urls")
p.add_argument("--gl", action='store_true', help="Add gitlab.com")
p.add_argument("--gh", action='store_true', help="Add github.com")
p.add_argument("--gs", action='store_true', help="Add gitlab.science.gc.ca")
p.add_argument("--remote", "-r", help="Name of remote")
p.add_argument("name", nargs='?', help="basename of the repo")

args = p.parse_args()

def add_push_url(name, remote="origin", host="github.com", user="philippecarphin"):
    return subprocess.run(f'git remote set-url origin --push --add git@{host}:{user}/{name}', shell=True)


if args.gl:
    add_push_url(args.name, remote=args.remote, host="gitlab.com", user="philippecarphin")
if args.gh:
    add_push_url(args.name, remote=args.remote, host="github.com", user="philippecarphin")
if args.gs:
    add_push_url(args.name, remote=args.remote, host="gitlab.science.gc.ca", user="phc001")
