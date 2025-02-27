#!/usr/bin/env python3

# This demonstrates the use of `OSC 52` xterm control sequence to ask the
# terminal emulator to set the system clipboard to a string.
#
# Ref: https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h3-Operating-System-Commands
#
# The control sequence is `ESC ] 52 ; c ;` followed by the base64 encoding of
# the string, followed by `BEL` to terminate the sequence.
#

import base64
import sys
s = sys.stdin.read()[:-1]
print(f"String : {s}")
b64 = base64.b64encode(s.encode('utf-8'))
print(f"B64    : {b64}")

sys.stdout.write('\033]52;c;')
sys.stdout.write(b64.decode('ascii'))
sys.stdout.write('\007')
