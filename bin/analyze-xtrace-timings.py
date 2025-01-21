#
# Sort commands by time taken from an xtrace output.
#
# This relies on the PS4 format
#
#    PS4='+ ${EPOCHREALTIME}:${FUNCNAME[0]}:${LINENO}: '
#
# Note that ${EPOCHREATIME} only works with BASH 5+
#
# We shouldn't expect speed out of a bash script if the bash script is doing
# the actual work, but if it is acting as glue for multiple programs, then this
# can help us identify which ones are taking the most time.
#
# I used this for my prompt string.  It does a lot of git commands and these
# interact with the filesystem and can be quite slow so using this I was able
# to find some commands that I could get rid of by doing a better job of saving
# results of other commands.
#
import re
def line_to_item(line, i):
    words = re.split(' |:', line.strip(), 4)
    print(words)
    return {'time': float(words[1]), 'lineno': i, 'func': words[2], 'lineno': int(words[3]), 'cmd': words[4]}

total_time = 0.0
with open("x") as f:
    cmd_times = []
    prev = line_to_item(f.readline(), 1)
    i = 1
    for l in f:
        if not l.startswith('+'):
            prev['cmd'] += "\\n" + l.strip()
            continue
        try:
            cur = line_to_item(l, i)
        except IndexError as e:
            prev['cmd'] += "\\n" + l.strip()
            continue

        time = {'duration': cur['time'] - prev['time'], 'cmd': prev['cmd'], 'func': prev['func'], 'lineno': i}
        i += 1
        total_time += time['duration']
        cmd_times.append(time)
        prev = cur

for t in sorted(cmd_times, key=lambda item: item['duration']):
    print(f"{t['lineno']:4} {t['duration']:.8f} : {t['func']:<20} : {t['cmd']}")

print(f"Total time = {total_time}")
