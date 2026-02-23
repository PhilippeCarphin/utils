#!/usr/bin/env python3

import sys
import base64
import requests
import time
import argparse
import socket
import io
import pprint

DESCRIPTION = """ This demonstrates chunked sending for testing echo-server's
ability to receive chunk encoded requests.  It first sends a basic HTTP request
line and headers, then sends the body of the request (the contents of a file)
using chunk encoding: send a chunk size N in hexadecimal, sends N bytes, sends
'\\r\\n'.  The receiver knows the transfer is done when it receives the value
'0' as a chunk size."""

def get_args():
    p = argparse.ArgumentParser(description=DESCRIPTION)
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=5447)
    p.add_argument("--input", "-i")
    p.add_argument("--chunk-size", "-c", type=int, default=20)
    p.add_argument("--period", "-T", type=float, default=0.1)
    return p.parse_args()

def main():
    args = get_args()
    input_stream = open(args.input, 'rb') if args.input else sys.stdin.buffer

    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        s.connect((args.host, args.port))
    except Exception as e:
        print(f"{type(e).__name__}: {e}")
        return 1

    do_send(input_stream, s, args.chunk_size, args.period)

    do_recv(s)

    s.close()

def do_send(input_stream, s, chunk_size, period):
    s.send(b"POST / HTTP/1.1\r\n")
    s.send(b"Access-Control-Allow-Origin: *\r\n")
    s.send(b"Content-type: text/event-stream\r\n")
    s.send(b"Transfer-Encoding: chunked\r\n")
    s.send(b"BingBong: b64\r\n")
    s.send(b"\r\n")
    while True:
        chunk = input_stream.read(chunk_size)
        if chunk:
            s.send(f"{len(chunk):x}\r\n".encode("UTF-8"))
            s.send(chunk + b"\r\n")
        else:
            s.send(b"0\r\n")
            break
        time.sleep(period)

def read_line(s):
    """ Read one byte at a time until we find a '\\n' ignoring '\\r' """
    l = io.BytesIO()
    while True:
        c = s.recv(1)
        if c == b'\r': continue
        if c == b'\n': break
        l.write(c)
    return l.getvalue()

def do_recv(s):
    status_line = read_line(s)
    resp_headers = {}
    while True:
        line = read_line(s)
        if len(line) == 0:
            break
        try:
            k, v = [x.strip() for x in line.decode('UTF-8').split(':', maxsplit=1)]
        except ValueError as e:
            print(f"invalid header: {e}: line='{line}'")
            continue
        resp_headers[k] = v

    pprint.pprint(resp_headers)

    if 'Content-Length' in resp_headers:
        body = s.recv(int(resp_headers['Content-Length']))
        sys.stdout.buffer.write(body)


if __name__ == "__main__":
    sys.exit(main())
