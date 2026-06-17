
import subprocess, time, re, sys, os, shutil

PACKAGE = "com.mobile.legends"

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

print(f"Using adb: {ADB}")

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
