#!/usr/bin/env python3

import sys
import re
import os

if len(sys.argv) < 2:
    print(f'{progname} \033[1;31mERROR\033[0m Argument required', file=sys.stderr)
    sys.exit(1)

needle_re = re.compile(sys.argv[1])
paths = []
if ':' in sys.argv[2]:
    paths = sys.argv[2].split(':')
else:
    paths = sys.argv[2:]
# paths = sys.argv[2].split(':') if ':' in sys.argv else sys.argv[2:]
# paths = sys.argv[2:] if ':' not in sys.argv else sys.argv.split(':')
for p in map(lambda s: s.split(':'), sys.argv[2:]):
    paths += p

def find_results():
    results = set()
    for p in paths:
        files = os.listdir(p)
        for f in files:
            filename = os.path.join(p,f)
            if needle_re.match(f) and filename not in results:
                results.add(filename)
                yield filename

for f in find_results():
    print(f)

