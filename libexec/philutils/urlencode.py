#!/usr/bin/env python3

import urllib.parse
import sys
import argparse

DESCRIPTION = """Command line interface to the urllib.parse.quote (encoding)
and urllib.parse.unquote (decoding) functions in the python package urllib.

Reads from stdin and prints the encoded or decoded URL"""
p = argparse.ArgumentParser()
p.add_argument("--decode", "-d", action='count', help="Set to decoding mode.  Use -dd to decode query values a second time")
p.add_argument("--split", action='store_true', help="Split the URL an print everything on separate lines")
p.add_argument("--quote-slash", action='store_true')
args = p.parse_args()
print(args)

url = sys.stdin.read().strip()


if args.decode:
    if args.split:
        parts = urllib.parse.urlparse(url)
        query = parts.query.split('&')
        print(f"scheme: \033[4m{parts.scheme}\033[0m")
        print(f"netloc: \033[1;35m{parts.netloc}\033[0m")
        print(f"path:   \033[36m{parts.path}\033[0m")
        if parts.params:
            print(f"params: \033[34m{parts.params}\033[0m")
        print(f"query: ...")
        if parts.query:
            for qp in query:
                key, value = map(urllib.parse.unquote, qp.split('=', 1))
                if args.decode > 1:
                    value = urllib.parse.unquote(value)
                print(f"    \033[1;33m{key}\033[0m=\033[32m{value}\033[0m")
        if parts.fragment:
            print(f"fragment: \033[34m{parts.fragment}\033[0m")
    else:
        print(urllib.parse.unquote(url))
else:
    safe = '' if args.quote_slash else '/'
    print(urllib.parse.quote(url, safe=safe))
