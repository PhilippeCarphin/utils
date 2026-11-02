#!/usr/bin/python3
import json
import os
import argparse
import subprocess
import pprint
import sys

def get_parser():
    p = argparse.ArgumentParser()
    p.add_argument("name", default=os.path.basename(os.getcwd()))
    return p

args = get_parser().parse_args()

if not os.path.isfile(os.path.expanduser('~/.ssh/tokens/github_token.txt')):
    print(f"ERROR: A github access token must be present as a single line in ~/.ssh/tokens/github_token.txt")
    sys.exit(1)

token = open(os.path.expanduser('~/.ssh/tokens/github_token.txt')).read()

# https://developer.github.com/v3/repos/#create
resp = requests.post(
    'https://api.github.com/user/repos',
    headers={'Authorization': f'token {token}'},
    json={'name', args.name}
)

if resp.status_code != 200:
    print(f"POST request failed")
    sys.exit(1)

cmd = ['git', 'remote', 'add', 'origin', response['clone_url']]
print(f"Adding repo: {' '.join(cmd)}")
subprocess.call(cmd)
