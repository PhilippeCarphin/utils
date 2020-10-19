#!/usr/bin/python3
import json
import os
import sys
import subprocess
import pprint

if len(sys.argv) < 2:
    name = os.path.basename(os.getcwd())
else:
    name = sys.argv[1]

message_ = {
        "name": name,
        }

message = json.dumps(message_)

# https://developer.github.com/v3/repos/#create
with open(os.path.expanduser('~/.ssh/tokens/github_token.txt'), 'r') as f:
    token = f.read()

curl_cmd = ['curl', '-X', 'POST', '-H', f'Authorization: token {token}', '-d', message, 'https://api.github.com/user/repos']

print(f'curl_cmd = {curl_cmd}')

def request_successful(response):
    if 'errors' in response:
        return False
    if 'message' in response:
        # Some responses for failures don't have an 'errors' attribute
        return False
    return 'url' in response

response = json.loads(subprocess.check_output(curl_cmd))
if not request_successful(response):
    print("Unable to create repository")
    pprint.pprint(response)
    quit(1)
else:
    print(f"Repo '{response['clone-url']}' created")

cmd = ['git', 'remote', 'add', 'origin', response['clone_url']]
print(f"Adding repo: {' '.join(cmd)}")
subprocess.call(cmd)
# subprocess.call(['git', 'push', '-u', 'origin', 'master'])
