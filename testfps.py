#!/usr/bin/env python3
import subprocess, time, re, sys

PACKAGE = "com.garena.game.codm"

def adb(cmd):
    try:
        return subprocess.check_output(
            ['adb', 'shell', 'su', '-c', cmd],
            stderr=subprocess.DEVNULL, timeout=8
        ).decode('utf-8', errors='replace')
    except:
        return None

prev_frame = None
prev_time  = None

def get_fps(dump):
    global prev_frame, prev_time
    m = re.search(
        r'SurfaceView\[' + re.escape(PACKAGE) + r'[^\]]*\]\(BLAST\).*?frame=(\d+)',
        dump, re.DOTALL
    )
    if not m:
        return None
    frame = int(m.group(1))
    now   = time.monotonic()
    if prev_frame is None:
        prev_frame, prev_time = frame, now
        return None
    fps = (frame - prev_frame) / (now - prev_time)
    prev_frame, prev_time = frame, now
    return fps if fps >= 0 else None

# warm up
dump = adb('dumpsys SurfaceFlinger')
if dump: get_fps(dump)
time.sleep(1)

try:
    while True:
        dump = adb('dumpsys SurfaceFlinger')
        fps  = get_fps(dump) if dump else None
        ts   = time.strftime("%H:%M:%S")
        print(f"[{ts}]  FPS: {fps:.1f}" if fps is not None else f"[{ts}]  FPS: ---")
        time.sleep(1)
except KeyboardInterrupt:
    print("\nStopped.")