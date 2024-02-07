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
import requests

check_jq = subprocess.run(['which', 'jq'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
use_jq = (check_jq.returncode == 0)

DESCRIPTION="Launch a server that prints out POST requests it receives"

def get_args():
    p = argparse.ArgumentParser(description=DESCRIPTION)
    p.add_argument("--port", "-p", type=int, help="Port to listen on", default=5447)
    p.add_argument("--host", help="Host to listen on", default="0.0.0.0")
    p.add_argument("--curl-notes", action='store_true', help="Print curl notes and exit")
    p.add_argument("--to-curl", action='store_true', help="Print equivalent cURL request of received requests")
    p.add_argument("--forward", help="Address to forward request to")
    return p.parse_args()

class MyServer(http.server.BaseHTTPRequestHandler):
    def generic_handler(self,method):
        qp = urllib.parse.urlparse(self.path)
        path, query = qp.path, qp.query
        print(f"\n\033[1;4mIncoming \033[34m{method}\033[39m request on path = \033[35m{path}\033[0m")
        print(self.requestline)

        #
        # Print urldecoded query parameters
        #
        if query:
            print(f"Query Parameters\n================\033[35m")
            for k,v in map(lambda kv: kv.split("="), query.split('&')): # What's the point of urlparse if I have to do this myself?
                v = urllib.parse.unquote(v)
                print(f"{k}: {v}")
            print("\033[0m", end='')
        #
        # Print headers
        #
        print(f"Headers\n=======\033[36m")
        for k,v in self.headers.items():
            print(f"\033[36m'{k}': '{v}'\033[0m")
        #
        # Print body in various ways depending on type
        #
        request_dict = None
        if 'Content-Length' in self.headers:
            content_length = int(self.headers['Content-Length'])
            request_body = self.rfile.read(content_length).decode('utf-8')
            if self.headers['Content-Type'] == 'application/json':
                print("JSON body\n==============")
                request_dict = json.loads(request_body)
                if use_jq:
                    p = subprocess.Popen(['jq'], stdin=subprocess.PIPE, universal_newlines=True)
                    p.stdin.write(request_body)
                    p.stdin.close()
                    p.wait()
                else:
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

        # These methods must be called in an order that reflects the HTTP protocol
        # order of 'status line, headers, payload' otherwise the response may
        # be rejected by the other application.
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(bytes(json.dumps({"message": "Hello World"},indent='    ') + '\n', 'utf-8'))

        #
        # Suppose you want to figure out what requests the gitlab-runner makes
        # to gitlab, you can register a runner normally but then edit the URL
        # in ~/.gitlab-runner/config.toml to be this echo server.  Call it with
        # --forward=<gitlab-url> and it will forward the request to that url
        if args.forward:
            headers = {**self.headers};
            print(headers)
            if 'Content-Length' in headers:
                del headers['Content-Length']
            if 'Host' in headers:
                if args.forward.startswith('https://'):
                    headers['Host'] = args.forward[8:]
                elif args.forward.startswith('http://'):
                    headers['Host'] = args.forward[7:]
                else:
                    headers['Host'] = args.forward
            if request_dict:
                headers['Content-Type'] = 'application/json'
                method_func = getattr(requests, method.lower())
                print(method_func)
                resp = method_func(
                        args.forward + self.path,
                        headers=headers,
                        data=bytes(json.dumps(request_dict), encoding='UTF-8'))
                if 'Content-Type' in resp.headers and resp.headers['Content-Type'] == 'application/json':
                    pprint(resp.json())
                else:
                    print("forwarded request: Only JSON responses supported")
            else:
                print("reqest forwarding: Only requests with JSON payload can be forwarded")
        if args.to_curl:
            print(f"CURL request")
            print(f"curl -X {method} \\")
            for k,v in self.headers.items():
                if k == 'Host':
                    print(f'    -H "{k}: ${{host}}" \\')
                elif k == 'Content-Length':
                    # cURL will compute the content lenght automatically and add
                    # it to the headers of the request without us having to specify
                    # it on the command line
                    continue
                else:
                    print(f'    -H "{k}: {v}" \\')
            if request_dict:
                print(f"    --data '{json.dumps(request_dict)}' \\")
            print(f"    \"$URL{self.path}\"")

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
