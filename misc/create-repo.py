#!/usr/bin/python
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

curl_cmd = ['curl', '-u', 'philippecarphin', '-d', message, 'https://api.github.com/user/repos']

response = json.loads(subprocess.check_output(curl_cmd))

if 'errors' in response:
    print("Unable to create repository")
    pprint.pprint(response)
    quit(1)

subprocess.call(['git', 'remote' 'add' 'origin' 'https://github.com/philippecarphin/' + name])
subprocess.call(['git', 'push', '-u', 'origin', 'master'])
