#!/usr/bin/env python3

import http.server
from pprint import pprint
import json
import argparse
import sys

DESCRIPTION="Launch a server that prints out POST requests it receives"

def get_args():
    p = argparse.ArgumentParser(description=DESCRIPTION)
    p.add_argument("--port", "-p", type=int, help="Port to listen on", default=5447)
    p.add_argument("--host", help="Host to listen on", default="0.0.0.0")
    p.add_argument("--curl-notes", action='store_true', help="Print curl notes and exit")
    return p.parse_args()

class MyServer(http.server.BaseHTTPRequestHandler):
    def generic_handler(self):
        print(f"Headers\n=======\n\n\033[36m{str(self.headers).strip()}\033[0m\n")
        if 'Content-Length' in self.headers:
            content_length = int(self.headers['Content-Length'])
            request_body = self.rfile.read(content_length).decode('utf-8')
            if 'Content-Type' in self.headers and self.headers['Content-Type'] == 'application/json':
                request_dict = json.loads(request_body)
                print("JSON body\n==============\n")
                print("\033[1;32m", end="")
                pprint(request_dict)
                print("\033[0m", end="")
                print()
            else:
                print(f"Request body\n============\n\n\033[1;33m{request_body}\033[0m\n")

        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(bytes(json.dumps({"message": "Hello World"},indent='    ') + '\n', 'utf-8'))
        self.send_response(200)

    def do_GET(self):
        print(f"Incoming \033[1;34mGET\033[0m request on path = \033[35m{self.path}\033[0m")
        self.generic_handler()
    def do_POST(self):
        print(f"Incoming \033[1;34mPOST\033[0m request on path = \033[35m{self.path}\033[0m")
        self.generic_handler()
    def do_DELETE(self):
        print(f"Incoming \033[1;34mDELETE\033[0m request on path = \033[35m{self.path}\033[0m")
        self.generic_handler()
    def do_PUT(self):
        print(f"Incoming \033[1;34mPUT\033[0m request on path = \033[35m{self.path}\033[0m")
        self.generic_handler()

args = get_args()
if args.curl_notes:
    print("""Example request:

    curl http://0.0.0.0:5447/asdf -X POST --http0.9 -H "Content-Type: application/json" -d '{"message": "HELLO WORLD","foo":"bar"}'

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

server.serve_forever()
