#!/usr/bin/env -S python3 -u
import argparse
import http.cookies
import http.server
import io
import json
import logging
import multipart
import pprint
import re
import requests
import shutil
import socket
import ssl
import subprocess
import sys
import urllib.parse

DESCRIPTION="Launch a server that prints out POST requests it receives"

USE_COLOR = sys.stdout.isatty()

def color(code, text):
    if USE_COLOR:
        return f"\033[{code}m{text}\033[0m"
    return str(text)

def get_args():
    p = argparse.ArgumentParser(description=DESCRIPTION)
    p.add_argument("--port", "-p", type=int, help="Port to listen on", default=5447)
    p.add_argument("--host", help="Host to listen on", default="127.0.0.1")
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
    timeout = 30

    def log_message(self, format, *args):
        logger.debug("http: " + format % args)

    def generic_handler(self,method):
        print(f"\n{color('1;4', 'Incoming')} {color('34', method)}")
        self.response_dict = {
            'warnings': [],
            'info': [],
        }
        self.response_headers = {}
        self.response_dict['method'] = method
        try:
            self.process_request_line()
            self.get_tcp_info()
            self.print_headers()
            self.set_cors_stuff(method)

            if self.server.args.forward:
                return self.forward_request(method, self.server.args.forward)

            self.print_body()
            self.setup_response()
        except (BrokenPipeError, ConnectionResetError, socket.timeout, TimeoutError) as e:
            logger.warning(f"Client went away while handling {method}: {e}")
            self.close_connection = True
        except Exception as e:
            logger.exception(f"Error handling {method} request")
            self.send_error_response(f"{type(e).__name__}: {e}")
        print("End self.generic_handler")

    def send_error_response(self, message):
        try:
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            body = (json.dumps({'error': message}, indent='    ') + '\n').encode('utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Connection', 'close')
            self.end_headers()
            if self.command != 'HEAD':
                self.wfile.write(body)
        except Exception:
            self.close_connection = True

    def setup_response(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        body = bytes(json.dumps(self.response_dict, indent='    ') + '\n', 'utf-8')
        self.response_headers['Content-Length'] = len(body)
        if self.response_headers:
            for k,v in self.response_headers.items():
                if k == 'Connection':
                    continue
                self.send_header(k,v)
        self.send_header('Connection', 'close')
        self.end_headers()
        if self.command != 'HEAD':
            self.wfile.write(body)

    def get_tcp_info(self):
        self.response_dict["client_address"] = self.client_address
        print(color('1;35', f"Request origin address: {self.client_address}"))
        print(color('1;35', f"Request connection: {self.connection}"))
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
        if not query:
            return
        query_dict = {}
        print(color('35', "Query Parameters\n================"))
        query_parts = query.split('&')
        for kv in query_parts:
            if not kv:
                continue
            if '=' not in kv:
                err = f"Query part '{kv}' does not contain equal sign"
                self.response_dict['warnings'].append(err)
                continue
            k, v = kv.split("=", 1)
            k = urllib.parse.unquote(k)
            v = urllib.parse.unquote(v)
            print(color('35', f"{k}: {v}"))
            if k in query_dict:
                if isinstance(query_dict[k], list):
                    query_dict[k].append(v)
                else:
                    query_dict[k] = [query_dict[k], v]
            else:
                query_dict[k] = v
        self.response_dict['query'] = query_dict

    def print_body(self):
        if 'Content-Length' in self.headers:
            self.print_body_from_request_with_content_length()
        elif self.headers.get('Transfer-Encoding', '').lower() == 'chunked':
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
            except ValueError:
                logger.error(f"Could not convert '{line}' to integer base 16")
                return
            if l == 0:
                logger.debug("zero sized chunk indicates end of stream")
                break
            logger.debug(f"Got hex integer {l:x} ({l}), waiting for {l} bytes")
            c = self.rfile.read(l)
            if not self.read_crlf():
                logger.error("Chunk was not followed by '\\r\\n' or '\\n' waiting for connection to close")
                return
            logger.debug(f"Chunk content: {c!r}")
            sys.stdout.buffer.write(c)
            if logger.level == logging.DEBUG and not c.endswith(b'\n'):
                sys.stdout.buffer.write(b'\n')
            chunks.append(c.decode('UTF-8', errors='replace'))
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
                return True
            logger.debug(f"read '\\r' but not followed by '\\n': {lf!r}")
            return False
        elif cr_or_lf == b'\n':
            logger.debug(f"read '\\n'")
            return True
        logger.debug(f"Failed to read \\r or \\n: {cr_or_lf!r}")
        return False

    def print_body_from_request_with_content_length(self):
        try:
            content_length = int(self.headers['Content-Length'])
        except ValueError:
            err = f"Malformed 'Content-Length' header: {self.headers['Content-Length']!r}"
            self.response_dict['warnings'].append(err)
            logger.error(err)
            return None
        request_body_data = self.rfile.read(content_length)
        request_body = request_body_data.decode('utf-8', errors='replace')
        content_type = self.headers.get('Content-Type', '')
        if content_type == 'application/json':
            print("JSON body\n=========")
            try:
                request_dict = json.loads(request_body)
                self.response_dict['json-body'] = request_dict
                if use_jq:
                    print_with_jq(request_body)
                else:
                    pprint.pprint(request_dict)
            except ValueError as e:
                err = f"Body is not valid JSON: {e}"
                self.response_dict['warnings'].append(err)
                logger.error(err)
                self.response_dict['request-body'] = request_body
                print(color('1;33', request_body))
        elif content_type.startswith('multipart/form-data'):
            self.print_multipart(request_body_data, content_type)
        else:
            self.response_dict['request-body'] = request_body
            print(f"\nRequest body\n============\n{color('1;33', request_body)}")
        return request_body_data

    def print_multipart(self, request_body_data, content_type):
        self.response_dict['form-data'] = {}
        print("Form data\n=========")
        m = re.search(r'boundary="?([^";]+)"?', content_type)
        if not m:
            err = f"Could not find boundary in Content-Type '{content_type}'"
            self.response_dict['warnings'].append(err)
            logger.error(err)
            return
        boundary = m.group(1)
        logger.debug(f"boundary = '{boundary}'")
        parser = multipart.MultipartParser(io.BytesIO(request_body_data), boundary)
        for item in parser.parts():
            try:
                self.response_dict['form-data'][item.name] = item.value
                print(color('1;33', f"Form item: '{item.name}': '{item.value}'"))
            except Exception as e:
                err = f"Could not process multipart item '{getattr(item, 'name', '<unknown>')}': {e}"
                self.response_dict['warnings'].append(err)
                logger.error(err)

    def print_headers(self):
        header_dict = {}
        print(color('36', "Headers\n======="))
        for k,v in self.headers.items():
            print(color('36', f"'{k}': '{v}'"))
            if k.lower() == 'cookie':
                try:
                    header_dict['Cookie'] = parse_cookie(v)
                except http.cookies.CookieError as e:
                    self.response_dict['warnings'].append(f"Malformed 'Cookie' header: {e}")
                    header_dict['Cookie'] = v
            else:
                if k in header_dict:
                    if isinstance(header_dict[k], list):
                        header_dict[k].append(v)
                    else:
                        header_dict[k] = [header_dict[k], v]
                else:
                    header_dict[k] = v
        self.response_dict['headers'] = header_dict


    def set_cors_stuff(self, method):
        print(f"CORS stuff\n==========")
        args = self.server.args
        origin = None
        origin_domain = None
        if 'Origin' in self.headers:
            origin = self.headers['Origin']
            origin_domain = urllib.parse.urlsplit(origin).netloc
            msg = f"Origin domain is '{origin_domain}'"
        else:
            msg = f"No 'Origin' in header.  This should have been set by the user agent"
        print(color('38;5;208', msg))
        self.response_dict['info'].append(msg)

        if origin and args.allowed_origins and origin_domain in args.allowed_origins:
            msg = f"Origin {origin} is in allowed hosts"
            print(color('38;5;208', msg))
            self.response_dict['info'].append(msg)
            logging.info(msg)
            self.response_headers["Access-Control-Allow-Origin"] = origin
        elif 'Sec-Fetch-Site' in self.headers and self.headers['Sec-Fetch-Site'] == 'same-origin':
            msg = f"Same origin request.  No CORS header needed"
            print(color('38;5;208', msg))
            self.response_dict['info'].append(msg)
        else:
            msg = f"Origin '{origin}' is not allowed but for demonstration purposes, we are sending a response anyway"
            print(color('38;5;208', msg))
            self.response_dict['info'].append(msg)
        #
        # CORS Preflight: Assume that the only time we get a request with
        # method OPTIONS, that it is a CORS preflight request.
        #
        if method == "OPTIONS":
            if origin:
                self.response_headers['Access-Control-Allow-Origin'] = origin
            self.response_headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
            requested_headers = self.headers.get('Access-Control-Request-Headers')
            if requested_headers:
                self.response_headers['Access-Control-Allow-Headers'] = requested_headers
            self.response_headers['Access-Control-Max-Age'] = '86400'

    def chunk_gen_or_data(self):
        if self.headers.get('Transfer-Encoding', '').lower() == 'chunked':
            return self.chunk_gen()
        elif 'Content-Length' in self.headers:
            try:
                content_length = int(self.headers['Content-Length'])
            except ValueError:
                err = f"Malformed 'Content-Length' header: {self.headers['Content-Length']!r}"
                self.response_dict['warnings'].append(err)
                logger.error(err)
                return None
            data_to_forward = self.rfile.read(content_length)
            logger.debug(f"data_to_forward: {data_to_forward!r}")
            return data_to_forward
        else:
            return None

    def chunk_gen(self):
        """ Generator providing the chunks of this request or the body """
        while True:
            line = self.rfile.readline().strip()
            size = int(line, 16)
            if size == 0:
                logger.debug("zero sized chunk indicates end of stream")
                return
            c = self.rfile.read(size)
            self.rfile.read(2)
            logger.debug(f"chunk_to_forward: {c!r}")
            yield c

    def forward_request(self, method, forward):
        logger.info(f"Forwarding request to {forward}")
        headers = dict(self.headers.items())
        # Hop-by-hop and framing headers are re-derived by the requests
        # library from the data we pass it.
        for hop_by_hop in ('Connection', 'Content-Length', 'Transfer-Encoding'):
            headers.pop(hop_by_hop, None)
        sp = urllib.parse.urlsplit(forward)
        if sp.scheme:
            url = f"{sp.scheme}://{sp.netloc}{sp.path}" + self.path
            host = sp.netloc
        else:
            url = forward + self.path
            host = forward
        if 'Host' in headers:
            headers['Host'] = host
        logger.debug(f"Forwarding with headers: {headers}")
        method_func = getattr(requests, method.lower())

        resp = method_func(
                url, # self.path includes query
                headers=headers,
                data=self.chunk_gen_or_data()
        )

        logger.info(f"Forwarded response status: {resp.status_code}")
        logger.debug(f"response headers: {dict(resp.headers)}")
        response_content_type = resp.headers.get('Content-Type', '')
        if response_content_type.startswith('application/json'):
            try:
                pprint.pprint(resp.json())
            except ValueError as e:
                logger.error(f"Could not parse forwarded response as JSON: {e}")
        elif 'Transfer-Encoding' in resp.headers and resp.headers['Transfer-Encoding'].lower() == 'chunked':
            print("Chunked response to forwarded request")
        else:
            print(f"resp.text: {resp.text}")

        logger.debug("Sending response received from forwarded request")
        self.send_response(resp.status_code)
        is_chunked_response = ('Transfer-Encoding' in resp.headers
                and resp.headers['Transfer-Encoding'].lower() == 'chunked')
        if resp.headers:
            for k,v in resp.headers.items():
                # We send the response back to the client un-chunked and
                # un-encoded, so we strip those headers and re-add the
                # framing headers that apply to *our* response below.
                if k.lower() in ('connection', 'transfer-encoding', 'content-length', 'content-encoding'):
                    continue
                self.send_header(k,v)
        if is_chunked_response:
            self.send_header('Transfer-Encoding', 'chunked')
        else:
            self.send_header('Content-Length', str(len(resp.content)))
        self.end_headers()

        if is_chunked_response:
            body = io.BytesIO()
            for chunk in resp.iter_content(chunk_size=1024):
                self.wfile.write(f"{len(chunk):x}".encode('UTF-8'))
                self.wfile.write(b'\r\n')
                self.wfile.write(chunk)
                self.wfile.write(b'\r\n')
                body.write(chunk)
            self.wfile.write(b'0\r\n\r\n')
            try:
                pprint.pprint(json.loads(body.getvalue().decode('UTF-8')))
            except ValueError:
                logger.debug("Forwarded chunked response body is not JSON")
        else:
            self.wfile.write(resp.content)
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
        self.generic_handler("PATCH")
    def do_HEAD(self):
        self.generic_handler("HEAD")

def print_with_jq(request_body):
    try:
        p = subprocess.run(['jq'], input=request_body.encode('utf-8'))
    except FileNotFoundError:
        logger.error("jq not found")
        return
    if p.returncode != 0:
        logger.error(f"jq exited with status {p.returncode}")

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

use_jq = shutil.which('jq') is not None

if args.curl_notes:
    scheme = 'https' if (args.cert and args.key) else 'http'
    host = '127.0.0.1' if args.host in ('0.0.0.0', '::') else args.host
    base = f"{scheme}://{host}:{args.port}"
    notes = f"""Curl examples for this server:

# GET with query parameters
curl -s {base}/?hello=world

# POST a JSON body
curl -s {base}/ -H 'Content-Type: application/json' -d '{{"hello": "world"}}'

# POST form data
curl -s {base}/ -d 'hello=world'

# POST multipart form data
curl -s {base}/ -F 'hello=world' -F 'file=@/path/to/file'

# POST a chunked encoded body
curl -s {base}/ -H 'Transfer-Encoding: chunked' --data-binary @/path/to/file
"""
    if args.forward:
        notes += f"\nRequests are forwarded to {args.forward}\n"
    print(notes)
    sys.exit(0)

server = http.server.ThreadingHTTPServer((args.host, args.port), MyServer)
server.args = args
server.daemon_threads = True

if args.cert and args.key:
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    try:
        context.load_cert_chain(args.cert, args.key)
    except (ssl.SSLError, OSError) as e:
        print(f"Could not load --cert/--key: {e}", file=sys.stderr)
        sys.exit(1)
    server.socket = context.wrap_socket(server.socket, server_side=True)

scheme = 'https' if (args.cert and args.key) else 'http'
print(f"Server listening on address : {color('1;33', args.host)}, port {color('1;34', str(args.port))} ({scheme})")

try:
    server.serve_forever()
except KeyboardInterrupt:
    sys.exit(130)
