#!/usr/bin/env -S python3 -u
import argparse
import http.cookies
import http.server
import io
import json
import logging
import multipart
import pprint
import requests
import subprocess
import sys
import urllib

DESCRIPTION="Launch a server that prints out POST requests it receives"

def get_args():
    p = argparse.ArgumentParser(description=DESCRIPTION)
    p.add_argument("--port", "-p", type=int, help="Port to listen on", default=5447)
    p.add_argument("--host", help="Host to listen on", default="0.0.0.0")
    p.add_argument("--curl-notes", action='store_true', help="Print curl notes and exit")
    p.add_argument("--forward", help="Address to forward request to")
    p.add_argument("--allowed-origins", help="Comma separated list of allowed origins")
    p.add_argument("--debug", action='store_true')
    p.add_argument("--cert")
    p.add_argument("--key")
    args = p.parse_args()
    if args.allowed_origins:
        args.allowed_origins = args.allowed_origins.split(",")
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
    protocol_version = "HTTP/1.1"

    def generic_handler(self,method):
        print(f"\n\033[1;4mIncoming \033[34m{method}\033[0m")
        self.response_dict = {
            'warnings': [],
            'info': [],
        }
        self.response_headers = {}
        self.response_dict['method'] = method
        self.process_request_line()
        self.get_tcp_info()
        self.print_headers()
        self.set_cors_stuff(method)

        if args.forward:
            return self.forward_request(method, args.forward)

        self.print_body()
        self.setup_response()
        print("End self.generic_handler")

    def setup_response(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        body = bytes(json.dumps(self.response_dict, indent='    ') + '\n', 'utf-8')
        self.response_headers['Content-Length'] = len(body)
        if self.response_headers:
            for k,v in self.response_headers.items():
                self.send_header(k,v)
        self.end_headers()
        self.wfile.write(body)

    def get_tcp_info(self):
        self.response_dict["client_address"] = self.client_address
        print(f"\033[1;35mRequest origin address: {self.client_address}\033[0m")
        print(f"\033[1;35mRequest connection: {self.connection}\033[0m")
        self.response_dict["connection"] = {
            "laddr": self.connection.getsockname(),
            "raddr": self.connection.getpeername()
        }

    def process_request_line(self):
        qp = urllib.parse.urlparse(self.path)
        path, query = qp.path, qp.query
        print(self.requestline)
        self.response_dict['requestline'] = self.requestline
        self.response_dict['full-path'] = self.path
        self.response_dict['path'] = path
        self.response_dict['raw-query'] = query
        self.print_query(query)

    def print_query(self, query):
        if query:
            self.response_dict['query'] = {}
            print(f"Query Parameters\n================\033[35m")
            query_parts = query.split('&')
            for kv in query_parts:
                try:
                    k, v = kv.split("=")
                    v = urllib.parse.unquote(v)
                    print(f"\033[35m{k}: {v}\033[0m")
                    self.response_dict['query'][k] = v
                except ValueError as e:
                    err = f"Query part '{kv}' does not contain equal sign"
                    self.response_dict['warnings'].append(err)
            print("\033[0m", end='')

    def print_body(self):
        if 'Content-Length' in self.headers:
            self.print_body_from_request_with_content_length()
        elif 'Transfer-Encoding' in self.headers and self.headers['Transfer-Encoding'] == 'chunked':
            self.print_body_from_chunk_encoded_request()
        else:
            logger.info("No 'Content-Length' or 'Transfer-Encoding' header which might be normal depending on the request type")

    def print_body_from_chunk_encoded_request(self):
        print(f"Chunk encoded body\n==================")
        chunks = []
        chunk_sizes = []
        while True:
            logger.debug(f"Waiting for hexadecimal integer on one line")
            line = self.rfile.readline().strip()
            try:
                l = int(line, 16)
            except ValueError as e:
                logger.error(f"Could not convert '{line}' to integer base 16: {e}")
                return
            if l == 0:
                logger.debug("zero sized chunk indicates end of stream")
                break
            logger.debug(f"Got hex integer {l:x} ({l}), waiting for {l} bytes")
            c = self.rfile.read(l)
            logger.debug(f"Got hex integer {l:x} ({l}), waiting for {l} bytes")
            if not self.read_crlf():
                logger.error("Chunk was not followed by '\\r\\n' or '\\n' waiting for connection to close")
                return
            logger.debug(f"Chunk content: {c!r}")
            sys.stdout.buffer.write(c)
            if logger.level == logging.DEBUG and not c.endswith(b'\n'):
                sys.stdout.buffer.write(b'\n')
            chunks.append(c.decode('UTF-8'))
            chunk_sizes.append(l)
        self.response_dict['chunks'] = chunks
        self.response_dict['chunk_sizes'] = chunk_sizes
        return ''.join(chunks)

    def read_crlf(self):
        cr_or_lf = self.rfile.read(1)
        if cr_or_lf == b'\r':
            lf = self.rfile.read(1)
            if lf == b'\n':
                logger.debug(f"read '\\r\\n'")
            else:
                logger.debug(f"Failed to read \\r or \\n")
                return False
        elif cr_or_lf == b'\n':
            logger.debug(f"read '\\n'")
        else:
            logger.debug(f"Failed to read \\r or \\n")
            return False
        return True

    def print_body_from_request_with_content_length(self):
        request_body_data = None
        content_length = int(self.headers['Content-Length'])
        request_body_data = self.rfile.read(content_length)
        request_body = request_body_data.decode('utf-8')
        if self.headers['Content-Type'] == 'application/json':
            print("JSON body\n=========")
            request_dict = json.loads(request_body)
            self.response_dict['json-body'] = request_dict
            if use_jq:
                print_with_jq(request_body)
            else:
                pprint.pprint(request_dict)
        elif self.headers['Content-Type'].startswith('multipart/form-data'):
            self.response_dict['form-data'] = {}
            print("Form data\n=========")
            s = request_body.split("\r")[0][2:]
            logger.debug(f"request_body = '{request_body}'")
            logger.debug(f"s = '{s}'")
            p = multipart.MultipartParser(io.BytesIO(multipart.to_bytes(request_body)),s)
            for item in p.parts():
                self.response_dict['form-data'][k] = v
                print(f"\033[1;33mForm item: '{item.name}': '{item.value}'\033[0m")
        else:
            self.response_dict['request-body'] = request_body
            print(f"\nRequest body\n============\n\033[1;33m{request_body}\033[0m")
        return request_body_data

    def print_headers(self):
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
        self.response_dict['Headers'] = header_dict


    def set_cors_stuff(self, method):
        print(f"CORS stuff\n==========")
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
        print(f"\033[38;5;208m{msg}\033[0m")
        self.response_dict['info'].append(msg)

        if origin and args.allowed_origins and origin_domain in args.allowed_origins:
            origin_allowed = True
            msg = f"Origin {origin} is in allowed hosts"
            self.response_dict['info'].append(msg)
            logging.info(msg)
            self.response_headers["Access-Control-Allow-Origin"] = origin
        elif 'Sec-Fetch-Site' in self.headers and self.headers['Sec-Fetch-Site'] == 'same-origin':
            origin_allowed = True
            msg = f"Same origin request.  No CORS header needed"
            print(f"\033[38;5;208m{msg}\033[0m")
            self.response_dict['info'].append(msg)
        else:
            msg = f"Origin '{origin}' is not allowed but for demonstration purposes, we are sending a response anyway"
            print(f"\033[38;5;208m{msg}\033[0m")
            self.response_dict['info'] = msg
        #
        # CORS Preflight: Assume that the only time we get a request with
        # method OPTIONS, that it is a CORS preflight request.
        #
        if method == "OPTIONS":
            self.response_headers['Access-Control-Allow-Origin'] = origin
            self.response_headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
            self.response_headers['Access-Control-Allow-Headers'] = 'X-PINGOTHER, Content-Type'
            self.response_headers['Access-Control-Max-Age'] = '86400'

    def chunk_gen_or_data(self):
        if 'Transfer-Encoding' in self.headers and self.headers['Transfer-Encoding'] == 'chunked':
            return self.chunk_gen()
        elif 'Content-Length' in self.headers:
            content_length = int(self.headers['Content-Length'])
            data_to_forward = self.rfile.read(content_length)
            print(f"data_to_forward: {data_to_forward}")
            return data_to_forward
        else:
            return None

    def chunk_gen(self):
        """ Generator providing the chunks of this request or the body """
        while True:
            size = int(self.rfile.readline().strip(), 16)
            if size == 0:
                print("zero sized chunk indicates end of stream")
                return
            c = self.rfile.read(size)
            crlf = self.rfile.read(2)
            print(f"chunk_to_forward: {c}")
            yield c

    def forward_request(self, method, forward):
        logging.info(f"Forwarding request to {args.forward}")
        headers = {**self.headers};
        if 'Connection' in headers and headers['Connection'] == 'keep-alive':
            del headers['Connection']
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
                data=self.chunk_gen_or_data()
        )

        print(f"resp={resp}")
        print(f"response headers: {resp.headers}")
        if 'Content-Length' in resp.headers:
            content_length = int(resp.headers['Content-Length'])
            if self.headers['Content-Type'] == 'application/json':
                pprint.pprint(resp.json())
            else:
                resp_body_data = self.rfile.read(content_length)
                resp_data = resp_body_data.decode('utf-8')
                print(f"resp_data: {resp_data}")
        elif 'Transfer-Encoding' in resp.headers and resp.headers['Transfer-Encoding'] == 'chunked':
            print("Chunked response to forwarded request")
        else:
            print("Unknowns transfer situation: no Content-Length and not chunked")
            print(f"resp.text: {resp.text}")

        logging.debug("Sending response received from forwarded request")
        self.send_response(resp.status_code)
        if resp.headers:
            for k,v in resp.headers.items():
                # We let the requests library handle the chunked response
                # so in our response to the requester, we send back an
                # un-chunked response so we need to change the headers of
                # *our* response accordingly.
                # if v == 'chunked': continue
                # This one felt like it had to do with chunking too
                # if k == 'Connection' and v == 'keep-alive': continue
                # We are also sending the response un-encoded so the we
                # remove this header too.
                # if k == 'Content-Encoding': continue
                self.send_header(k,v)
        self.end_headers()

        if 'Transfer-Encoding' in resp.headers and resp.headers['Transfer-Encoding'] == 'chunked':
            bingbong = io.BytesIO()
            last_chunk_size = 0
            for chunk in resp.iter_content(chunk_size=1024):
                self.wfile.write(f"{len(chunk):x}".encode('UTF-8'))
                self.wfile.write(b'\r\n')
                self.wfile.write(chunk)
                self.wfile.write(b'\r\n')
                last_chunk = chunk
                last_chunk_size = len(chunk)
                bingbong.write(chunk)
            self.wfile.write(b'0\r\n')
            pprint.pprint(json.loads(bingbong.getvalue().decode('UTF-8')))
            print(f"Last chunk: {last_chunk}")
            print(f"Last chunk size = {last_chunk_size}")
        else:
            data_to_send_back = resp.text.encode('UTF-8')
            print(f"Data to send back = {data_to_send_back}")
            self.wfile.write(data_to_send_back)
        print("End self.forward_request")

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
    def do_PATCH(self):
        print("PATCH BINGBONG")
        self.generic_handler("PATCH")

def print_with_jq(request_body):
    p = subprocess.Popen(['jq'], stdin=subprocess.PIPE, universal_newlines=True)
    p.stdin.write(request_body)
    p.stdin.close()
    p.wait()

args = get_args()

if sys.stderr.isatty():
    logging.addLevelName( logging.WARNING, f"\033[0;33m{logging.getLevelName(logging.WARNING)}\033[1;0m")
    logging.addLevelName( logging.ERROR,   f"\033[0;31m{logging.getLevelName(logging.ERROR)}\033[1;0m")
    logging.addLevelName( logging.INFO,    f"\033[0;35m{logging.getLevelName(logging.INFO)}\033[1;0m")
    logging.addLevelName( logging.DEBUG,   f"\033[36m{logging.getLevelName(logging.DEBUG)}\033[1;0m")
FORMAT = "[{levelname} - {funcName}()] {message}"
logging.basicConfig(level=(logging.DEBUG if args.debug else logging.INFO), format=FORMAT, style='{')
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG if args.debug else logging.INFO)

check_jq = subprocess.run(['which', 'jq'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
use_jq = (check_jq.returncode == 0)

server = http.server.HTTPServer((args.host, args.port), MyServer)

print(f"Server listening on address : \033[1;33m{args.host}\033[0m, port \033[1;34m{args.port}\033[0m")

try:
    server.serve_forever()
except KeyboardInterrupt:
    quit(130)
