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
    p.add_argument("--allowed-origins", help="Comma separated list of allowed origins")
    args = p.parse_args()
    if args.allowed_origins:
        args.allowed_origins = args.allowed_origins.split(",")
    return args

class MyServer(http.server.BaseHTTPRequestHandler):
    def generic_handler(self,method):
        response_dict = {}
        qp = urllib.parse.urlparse(self.path)
        path, query = qp.path, qp.query
        print(f"\n\033[1;4mIncoming \033[34m{method}\033[39m request on path = \033[35m{path}\033[0m")
        print(self.requestline)
        response_dict['method'] = method
        response_dict['requestline'] = self.requestline
        response_dict['full-path'] = self.path
        response_dict['path'] = path
        response_dict['raw-query'] = query
        response_dict['warnings'] = []
        response_dict['info'] = []

        response_headers = {}

        #
        # CORS stuff
        #
        origin = None
        origin_domain = None
        origin_allowed = False
        if 'Origin' in self.headers:
            origin = self.headers['Origin']
            if origin.startswith('https://'):
                origin_domain = origin[8:]
            elif origin.startswith('http://'):
                origin_domain = origin[7:]
            msg = f"Origin domain is '{origin_domain}'"
        else:
            msg = f"No 'Origin' in header.  This should have been set by the user agent"
        print(f"\033[1;35mINFO\033[0m: {msg}")
        response_dict['info'].append(msg)

        if origin and args.allowed_origins and origin_domain in args.allowed_origins:
            origin_allowed = True
            msg = f"Origin {origin} is in allowed hosts"
            response_dict['info'].append(msg)
            print(f"\033[1;35mINFO\033[0m: {msg}")
            response_headers["Access-Control-Allow-Origin"] = origin
        elif 'Sec-Fetch-Site' in self.headers and self.headers['Sec-Fetch-Site'] == 'same-origin':
            origin_allowed = True
            msg = f"Same origin request.  No CORS header needed"
            print(f"\033[1;35mINFO\033[0m: {msg}")
            response_dict['info'].append(msg)
        else:
            msg = f"Origin '{origin}' is not allowed but for demonstration purposes, we are sending a response anyway"
            print(f"\033[1;35mINFO\033[0m: {msg}")
            response_dict['info'] = msg
            # send_response(403)
            # return

        #
        # Print urldecoded query parameters
        #
        if query:
            response_dict['query'] = {}
            print(f"Query Parameters\n================\033[35m")
            query_parts = query.split('&')
            for kv in query_parts:
                try:
                    k, v = kv.split("=")
                    v = urllib.parse.unquote(v)
                    print(f"\033[35m{k}: {v}\033[0m")
                    response_dict['query'][k] = v
                except ValueError as e:
                    err = f"Query part '{kv}' does not contain equal sign"
                    response_dict['warnings'].append(err)
            # for k,v in map(lambda kv: kv.split("="), query.split('&')): # What's the point of urlparse if I have to do this myself?
            print("\033[0m", end='')
        #
        # Print headers
        #
        response_dict['Headers'] = {}
        print(f"Headers\n=======\033[36m")
        for k,v in self.headers.items():
            response_dict['Headers'][k] = [v]
            print(f"\033[36m'{k}': '{v}'\033[0m")
        #
        # Print body in various ways depending on type
        #
        request_dict = None
        request_body_data = None
        if 'Content-Length' in self.headers:
            content_length = int(self.headers['Content-Length'])
            request_body_data = self.rfile.read(content_length)
            request_body = request_body_data.decode('utf-8')
            if self.headers['Content-Type'] == 'application/json':
                print("JSON body\n==============")
                request_dict = json.loads(request_body)
                response_dict['json-body'] = request_dict
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
                response_dict['form-data'] = {}
                print("Form data\n=========")
                s = request_body.split("\r")[0][2:]
                print(f"DEBUG: request_body = '{request_body}'")
                print(f"DEBUG: s = '{s}'")
                p = multipart.MultipartParser(BytesIO(multipart.to_bytes(request_body)),s)
                for item in p.parts():
                    response_dict['form-data'][k] = v
                    print(f"\033[1;33mForm item: '{item.name}': '{item.value}'\033[0m")
            else:
                response_dict['request-body'] = request_body
                print(f"\nRequest body\n============\n\033[1;33m{request_body}\033[0m")

        # These methods must be called in an order that reflects the HTTP protocol
        # order of 'status line, headers, payload' otherwise the response may
        # be rejected by the other application.
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        if response_headers:
            for k,v in response_headers.items():
                self.send_header(k,v)
        self.end_headers()
        self.wfile.write(bytes(json.dumps(response_dict, indent='    ') + '\n', 'utf-8'))

        #
        # Suppose you want to figure out what requests the gitlab-runner makes
        # to gitlab, you can register a runner normally but then edit the URL
        # in ~/.gitlab-runner/config.toml to be this echo server.  Call it with
        # --forward=<gitlab-url> and it will forward the request to that url
        if args.forward:
            headers = {**self.headers};
            # print(headers)
            if 'Host' in headers:
                if args.forward.startswith('https://'):
                    headers['Host'] = args.forward[8:]
                elif args.forward.startswith('http://'):
                    headers['Host'] = args.forward[7:]
                else:
                    headers['Host'] = args.forward
            method_func = getattr(requests, method.lower())
            # print(method_func)
            resp = method_func(
                    args.forward + self.path,
                    headers=headers,
                    data=request_body_data
            )
            print(f"resp={resp}")
            print(f"response headers: {resp.headers}")
            if 'Content-Length' in resp.headers:
                content_length = int(resp.headers['Content-Length'])
                if self.headers['Content-Type'] == 'application/json':
                    pprint(resp.json())
                else:
                    resp_body_data = self.rfile.read(content_length)
                    resp_data = resp_body_data.decode('utf-8')
                    print(f"resp_data: {resp_data}")
            else:
                print("No 'Content-Length' in response headers of forwarded request")

            # if request_dict:
            #     # Probably we already have this header.
            #     headers['Content-Type'] = 'application/json'
            #     # Make the outgoing request have the same method as the
            #     # incoming request
            #     method_func = getattr(requests, method.lower())
            #     print(method_func)
            #     if 'Content-Type' in resp.headers and resp.headers['Content-Type'] == 'application/json':
            #         resp = method_func(
            #                 args.forward + self.path,
            #                 headers=headers,
            #                 data=bytes(json.dumps(request_dict), encoding='UTF-8'))
            #         pprint(resp.json())
            #         print("forwarded request: Only JSON responses supported")
            # else:
            #     print("reqest forwarding: Only requests with JSON payload can be forwarded")
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
