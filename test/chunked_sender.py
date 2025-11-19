import sys
import base64
import requests
import time

chunk_size=20

sys.stdout.buffer.write(b"""POST /new.html HTTP/1.1\r
Access-Control-Allow-Origin: *\r
Content-type: text/event-stream\r
Transfer-Encoding: chunked\r
BingBong: b64

""")

i=0
prev_chunk = "bingbong"
while True:
    # i+=1
    # if i > 100:
    #     break
    chunk = sys.stdin.buffer.read(chunk_size)

    if chunk:
        sys.stdout.buffer.write(f"{len(chunk):x}".encode("UTF-8"))
        sys.stdout.buffer.write(b"\r\n")
        sys.stdout.buffer.write(chunk)
        sys.stdout.buffer.write(b"\r\n")
    else:
        sys.stdout.write("0\r\n")
        break
    time.sleep(0.5)
