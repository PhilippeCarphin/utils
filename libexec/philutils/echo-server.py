#!/usr/bin/env python3

import http.server
from pprint import pprint
import json
import argparse
import sys
import multipart
from io import BytesIO
import subprocess
import urllib

check_jq = subprocess.run(['which', 'jq'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
use_jq = (check_jq.returncode == 0)

DESCRIPTION="Launch a server that prints out POST requests it receives"

def get_args():
    p = argparse.ArgumentParser(description=DESCRIPTION)
    p.add_argument("--port", "-p", type=int, help="Port to listen on", default=5447)
    p.add_argument("--host", help="Host to listen on", default="0.0.0.0")
    p.add_argument("--curl-notes", action='store_true', help="Print curl notes and exit")
    return p.parse_args()

class MyServer(http.server.BaseHTTPRequestHandler):
    def generic_handler(self,method):
        qp = urllib.parse.urlparse(self.path)
        path, query = qp.path, qp.query
        print(f"\n\033[1;4mIncoming \033[34m{method}\033[39m request on path = \033[35m{path}\033[0m")
        print(self.requestline)
        if query:
            print(f"Query Parameters\n================\033[35m")
            for k,v in map(lambda kv: kv.split("="), query.split('&')): # What's the point of urlparse if I have to do this myself?
                print(f"{k}: {v}")
            print("\033[0m", end='')
        print(f"Headers\n=======\033[36m")
        for k,v in self.headers.items():
            print(f"\033[36m'{k}': '{v}'\033[0m")
        if 'Content-Length' in self.headers:
            content_length = int(self.headers['Content-Length'])
            request_body = self.rfile.read(content_length).decode('utf-8')
            if self.headers['Content-Type'] == 'application/json':
                print("JSON body\n==============")
                if use_jq:
                    p = subprocess.Popen(['jq'], stdin=subprocess.PIPE, universal_newlines=True)
                    p.stdin.write(request_body)
                    p.stdin.close()
                    p.wait()
                else:
                    request_dict = json.loads(request_body)
                    print("\033[1;32m", end='')
                    pprint(request_dict)
                print("\033[0m", end='')
            elif self.headers['Content-Type'].startswith('multipart/form-data'):
                print("Form data\n=========")
                s = request_body.split("\r")[0][2:]
                p = multipart.MultipartParser(BytesIO(multipart.to_bytes(request_body)),s)
                parts = p.parts()
                while True:
                    try:
                        item = parts.pop()
                        print(f"\033[1;33mForm item: '{item.name}': '{item.value}'\033[0m")
                    except IndexError:
                        break
            else:
                print(f"\nRequest body\n============\n\033[1;33m{request_body}\033[0m")

        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        # json.dump({"message": "Hello World"}, self.wfile)
        self.wfile.write(bytes(json.dumps({"message": "Hello World"},indent='    ') + '\n', 'utf-8'))
        self.send_response(200)

    def do_GET(self):
        self.generic_handler("GET")
    def do_POST(self):
        self.generic_handler("POST")
    def do_DELETE(self):
        self.generic_handler("DELETE")
    def do_PUT(self):
        self.generic_handler("PUT")

args = get_args()
if args.curl_notes:
    print("""Example request:

    curl http://0.0.0.0:5447/asdf -X POST -H "Content-Type: application/json" -d '{"message": "HELLO WORLD","foo":"bar"}'

- Use `-X [POST,GET,PUT,DELETE]` to select the request type

- Use `-H "Content-Type:application/json"` etc to set the headers.  Use -H
  multiple times to send multiple headers. Spaces are allowed between colon
  and the value but not after the value. Spaces are not allowed between the
  key and the colon.

- Use `-d "..."` to set the payload for the request

- The `Content-Length` header is calculated automatically by cURL
""")
    sys.exit(0)


server = http.server.HTTPServer((args.host, args.port), MyServer)

print(f"Server listening on address : \033[1;33m{args.host}\033[0m, port \033[1;34m{args.port}\033[0m")

try:
    server.serve_forever()
except KeyboardInterrupt:
    quit(130)
