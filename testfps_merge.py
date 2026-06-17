#!/usr/bin/env python3
import subprocess, time, re, sys, os, shutil

# Default packages combined from both original scripts
PACKAGES = [
    "com.garena.game.codm", # from testfps.py
    "com.mobile.legends"    # from testfps_furkilazz.py
]

# Locate adb: env var > same folder as script / platform-tools > PATH
def find_adb():
    if os.environ.get("ADB"):
        return os.environ["ADB"]
    here = os.path.dirname(os.path.abspath(__file__))
    for cand in (
        os.path.join(here, "adb.exe"),
        os.path.join(here, "platform-tools", "adb.exe"),
        r"D:\platform-tools\adb.exe",
    ):
        if os.path.isfile(cand):
            return cand
    found = shutil.which("adb")
    if found:
        return found
    sys.exit("adb not found. Set the ADB env var or put adb.exe next to this script.")

ADB = find_adb()

def adb(cmd):
    try:
        return subprocess.check_output(
            [ADB, 'shell', 'su', '-c', cmd],
            stderr=subprocess.DEVNULL, timeout=8
        ).decode('utf-8', errors='replace')
    except Exception as e:
        print(f"  (adb error: {e})", file=sys.stderr)
        return None

prev_frame = None
prev_time  = None
current_pkg = None

def get_fps(dump):
    global prev_frame, prev_time, current_pkg
    
    frame = None
    matched_pkg = None
    
    # Use user-provided argument if present, otherwise check default packages
    packages_to_check = [sys.argv[1]] if len(sys.argv) > 1 else PACKAGES
    
    for pkg in packages_to_check:
        m = re.search(
            r'SurfaceView\[' + re.escape(pkg) + r'[^\]]*\]\(BLAST\).*?frame=(\d+)',
            dump, re.DOTALL
        )
        if m:
            frame = int(m.group(1))
            matched_pkg = pkg
            break
            
    if frame is None:
        # No matching package found running, reset tracking
        current_pkg = None
        prev_frame = None
        return None, None
        
    # If the active package changed (e.g. user switched games), reset the timer
    if matched_pkg != current_pkg:
        current_pkg = matched_pkg
        prev_frame = None
        
    now = time.monotonic()
    if prev_frame is None:
        prev_frame, prev_time = frame, now
        return None, matched_pkg
        
    fps = (frame - prev_frame) / (now - prev_time)
    prev_frame, prev_time = frame, now
    return (fps if fps >= 0 else None), matched_pkg

print(f"Using adb: {ADB}")
if len(sys.argv) > 1:
    print(f"Target package: {sys.argv[1]}")
else:
    print(f"Target packages: {', '.join(PACKAGES)}")
print("Tip: You can pass a specific package name as a command-line argument.")
print("-" * 50)

# warm up
dump = adb('dumpsys SurfaceFlinger')
if dump: get_fps(dump)
time.sleep(1)

try:
    while True:
        dump = adb('dumpsys SurfaceFlinger')
        fps, pkg = get_fps(dump) if dump else (None, None)
        ts = time.strftime("%H:%M:%S")
        if fps is not None:
            print(f"[{ts}]  [{pkg}] FPS: {fps:.1f}")
        else:
            print(f"[{ts}]  FPS: ---")
        time.sleep(1)
except KeyboardInterrupt:
    print("\nStopped.")
