# Consume squeezelite's stdout at a fixed byte rate so playback runs near real time without audio hardware.
import sys, time
RATE = int(sys.argv[1]) if len(sys.argv) > 1 else 600_000
CHUNK = RATE // 10
inp = sys.stdin.buffer
while True:
    t = time.monotonic()
    if not inp.read(CHUNK):
        break
    d = 0.1 - (time.monotonic() - t)
    if d > 0:
        time.sleep(d)
