import sys
import base64
import requests

chunk_size=10

# sys.stdout.write("""POST /new.html HTTP/1.1\r
# Access-Control-Allow-Origin: *\r
# Content-type: text/event-stream\r
# Transfer-Encoding: chunked\r
# BingBong: b64\r
# \r
# """)

def gen_chunks():
    i=0
    while True:
        i+=1
        if i > 100:
            break
        chunk = sys.stdin.buffer.read(chunk_size)
        if chunk:
            b64_chunk = base64.b64encode(chunk)
            print(f"{len(b64_chunk)}\r\n{b64_chunk}\r\n", file=sys.stderr)
            yield chunk
        else:
            return


        sys.stdout.buffer.write(f"{hex(len(b64_chunk))}".encode("UTF-8"))
        sys.stdout.buffer.write(b"\r\n")
        sys.stdout.buffer.write(b64_chunk)
        sys.stdout.buffer.write(b"\r\n")
        if len(chunk) < chunk_size:
            sys.stdout.write("0\r\n")
            break

# for c in gen_chunks():
#     print(f"chunk: {chunk}", file=sys.stderr)
resp = requests.post("http://ppp5login-002.science.gc.ca:1234", data=gen_chunks())
print(resp)
