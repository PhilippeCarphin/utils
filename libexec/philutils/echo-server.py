#!/usr/bin/env python3

import http.server
import http.cookies
from pprint import pprint
import json
import argparse
import sys
import multipart
from io import BytesIO
import subprocess
import urllib
import requests
import logging

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
    p.add_argument("--debug", action='store_true')
    p.add_argument("--cert")
    p.add_argument("--key")
    args = p.parse_args()
    if args.allowed_origins:
        args.allowed_origins = args.allowed_origins.split(",")
    if args.debug:
        logging.basicConfig(level=logging.DEBUG)
    if args.cert or args.key:
        if not (args.cert and args.key):
            p.error("Both or none of --cert and --key must be specified")
    return args


def parse_cookie(s):
    # Like I have observed in Clojure with ring.middleware.cookies, it looks
    # like the SimpleCookie object has all the attributes that could be put in a
    # Set-Cookie header even though here we are receiving cookies through the
    # Cookie header which I don't think can have any attributes.
    cookies = http.cookies.SimpleCookie()
    cookies.load(s)
    # This is what we could do to show the "expires", "path", "max-age"...
    # return [{"name": k, "value": v.value, "properties": v} for k,v in cookies.items()]
    return [{"name": k, "value": v.value} for k,v in cookies.items()]

class MyServer(http.server.BaseHTTPRequestHandler):
    def generic_handler(self,method):
        response_dict = {
            'warnings': [],
            'info': [],
        }
        response_headers = {}

        # TCP STUFF
        response_dict["client_address"] = self.client_address
        print(f"\033[1;35mRequest origin address: {self.client_address}\033[0m")
        print(f"\033[1;35mRequest connection: {self.connection}\033[0m")
        response_dict["connection"] = {
            "laddr": self.connection.getsockname(),
            "raddr": self.connection.getpeername()
        }

        # PATH AND METHOD
        qp = urllib.parse.urlparse(self.path)
        path, query = qp.path, qp.query
        print(f"\n\033[1;4mIncoming \033[34m{method}\033[39m request on path = \033[35m{path}\033[0m")
        print(self.requestline)
        response_dict['method'] = method
        response_dict['requestline'] = self.requestline
        response_dict['full-path'] = self.path
        response_dict['path'] = path
        response_dict['raw-query'] = query

        self.set_cors_stuff(method, response_dict, response_headers)
        self.print_query(query, response_dict)
        self.print_headers(response_dict)
        request_dict, request_body_data = self.print_body(response_dict)
        if args.to_curl:
            self.print_curl_request(method, request_dict)

        if args.forward:
            self.forward_request(method, request_body_data, args.forward)
        else:
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            if response_headers:
                for k,v in response_headers.items():
                    self.send_header(k,v)
            self.end_headers()
            self.wfile.write(bytes(json.dumps(response_dict, indent='    ') + '\n', 'utf-8'))

    def print_query(self, query, response_dict):
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
            print("\033[0m", end='')


    def print_body(self, response_dict):
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
                logging.debug(f"request_body = '{request_body}'")
                logging.debug(f"s = '{s}'")
                p = multipart.MultipartParser(BytesIO(multipart.to_bytes(request_body)),s)
                for item in p.parts():
                    response_dict['form-data'][k] = v
                    print(f"\033[1;33mForm item: '{item.name}': '{item.value}'\033[0m")
            else:
                response_dict['request-body'] = request_body
                print(f"\nRequest body\n============\n\033[1;33m{request_body}\033[0m")
        return request_dict, request_body_data


    def print_headers(self, response_dict):
        header_dict = {}
        print(f"Headers\n=======\033[36m")
        for k,v in self.headers.items():
            print(f"\033[36m'{k}': '{v}'\033[0m")
            if k in ['Cookie', 'cookie']:
                header_dict[k] = parse_cookie(v)
            else:
                if k in header_dict:
                    if isinstance(header_dict[k], list):
                        header_dict[k].append(v)
                    else:
                        heacer_dict[k] = [header_dict[k], v]
                else:
                    header_dict[k] = [v]
        response_dict['Headers'] = header_dict


    def set_cors_stuff(self, method, response_dict, response_headers):
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
        logging.info(msg)
        response_dict['info'].append(msg)

        if origin and args.allowed_origins and origin_domain in args.allowed_origins:
            origin_allowed = True
            msg = f"Origin {origin} is in allowed hosts"
            response_dict['info'].append(msg)
            logging.info(msg)
            response_headers["Access-Control-Allow-Origin"] = origin
        elif 'Sec-Fetch-Site' in self.headers and self.headers['Sec-Fetch-Site'] == 'same-origin':
            origin_allowed = True
            msg = f"Same origin request.  No CORS header needed"
            logging.info(msg)
            response_dict['info'].append(msg)
        else:
            msg = f"Origin '{origin}' is not allowed but for demonstration purposes, we are sending a response anyway"
            logging.info(msg)
            response_dict['info'] = msg

        #
        # CORS Preflight: Assume that the only time we get a request with
        # method OPTIONS, that it is a CORS preflight request.
        #
        if method == "OPTIONS":
            response_headers['Access-Control-Allow-Origin'] = origin
            response_headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
            response_headers['Access-Control-Allow-Headers'] = 'X-PINGOTHER, Content-Type'
            response_headers['Access-Control-Max-Age'] = '86400'


    def forward_request(self, method, data, forward):
        logging.info(f"Forwarding request to {args.forward}")
        headers = {**self.headers};
        print(f"headers={headers}")
        if 'Host' in headers:
            if forward.startswith('https://'):
                headers['Host'] = forward[8:]
            elif forward.startswith('http://'):
                headers['Host'] = forward[7:]
            else:
                headers['Host'] = forward
        method_func = getattr(requests, method.lower())

        resp = method_func(
                forward + self.path, # self.path includes query
                headers=headers,
                data=data
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
        elif 'Content-Type' in resp.headers and resp.headers['Content-Type'] == 'application/json':
            pprint(resp.json())
        else:
            print("No 'Content-Length' in response headers of forwarded request")
            print(resp.text)

        logging.debug("Sending response received from forwarded request")
        self.send_response(resp.status_code)
        if resp.headers:
            for k,v in resp.headers.items():
                # We let the requests library handle the chunked response
                # so in our response to the requester, we send back an
                # un-chunked response so we need to change the headers of
                # *our* response accordingly.
                if v == 'chunked': continue
                # This one felt like it had to do with chunking too
                if k == 'Connection' and v == 'keep-alive': continue
                # We are also sending the response un-encoded so the we
                # remove this header too.
                if k == 'Content-Encoding': continue
                self.send_header(k,v)
        self.end_headers()
        self.wfile.write(resp.text.encode('UTF-8'))


    def print_curl_request(self, method, request_dict):
        print(f"CURL request")
        print(f"curl -X {method} \\")
        for k,v in self.headers.items():
            if k == 'Host':
                print(f'    -H "{k}: ${{host}}" \\')
            elif k == 'Content-Length':
                # cURL will do the Content-Length header itself based on the data
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
    def do_OPTIONS(self):
        self.generic_handler("OPTIONS")

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
