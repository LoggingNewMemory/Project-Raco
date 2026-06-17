#!/usr/bin/env python3
"""
CODM Real-Time FPS Counter
Primary method: frame counter diff from BLAST layer (live, updates every poll)
Secondary method: vendor FPS ring buffer (used only when new entries appear)

Package: com.garena.game.codm
"""

import subprocess
import time
import re
import sys

PACKAGE       = "com.garena.game.codm"
POLL_INTERVAL = 1.0   # seconds


# ─────────────────────────────────────────────
# ADB root helper
# ─────────────────────────────────────────────
def adb(cmd_str, timeout=8):
    try:
        return subprocess.check_output(
            ['adb', 'shell', 'su', '-c', cmd_str],
            stderr=subprocess.DEVNULL,
            timeout=timeout
        ).decode('utf-8', errors='replace')
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
        return None


def sf_dump():
    return adb('dumpsys SurfaceFlinger', timeout=10)


# ─────────────────────────────────────────────
# METHOD A: Frame counter diff  ← PRIMARY
#
# Reads 'frame=XXXXX' from the live BLAST layer.
# Called on every poll; diffs frame count / elapsed time = real FPS.
#
#   Layer [1294] SurfaceView[...](BLAST)#1294
#     visible reason= buffer=... frame=13279 ...
# ─────────────────────────────────────────────
_prev_frame  = None
_prev_time   = None

def fps_from_framecounter(dump):
    global _prev_frame, _prev_time

    m = re.search(
        r'SurfaceView\[' + re.escape(PACKAGE) + r'[^\]]*\]\(BLAST\)#\d+[^\n]*\n'
        r'\s+visible reason=\s*buffer=\d+\s+frame=(\d+)',
        dump
    )
    if not m:
        # broader fallback: any line with (BLAST) then frame= nearby
        m = re.search(
            r'SurfaceView\[' + re.escape(PACKAGE) + r'[^\]]*\]\(BLAST\).*?frame=(\d+)',
            dump, re.DOTALL
        )
    if not m:
        return None

    frame = int(m.group(1))
    now   = time.monotonic()

    if _prev_frame is None:
        _prev_frame = frame
        _prev_time  = now
        return None

    delta_f = frame - _prev_frame
    delta_t = now   - _prev_time

    _prev_frame = frame
    _prev_time  = now

    if delta_t <= 0 or delta_f < 0:
        return None
    if delta_f == 0:
        return 0.0

    return delta_f / delta_t


# ─────────────────────────────────────────────
# METHOD B: Vendor ring buffer  ← SECONDARY
#
# Only used when a NEW entry appears (different index+timestamp than last read).
# Provides min/max frame time which the counter diff can't give us.
#
#   (4) 09:50:30.99  fps=29.99 dur=1000.22  max=42.42  min=24.70
# ─────────────────────────────────────────────
_last_rb_key = None   # (index, timestamp) of last seen entry

def fps_from_ringbuffer(dump):
    """Returns (fps, min_ft, max_ft) if a NEW ring buffer entry exists, else None."""
    global _last_rb_key

    rb_match = re.search(r'FPS ring buffer:(.*?)(?:\n[ \t]*\n|\Z)', dump, re.DOTALL)
    if not rb_match:
        return None

    entries = re.findall(
        r'\(\s*(\d+)\)\s+([\d:\.]+)\s+fps=([\d.]+)\s+dur=([\d.]+)\s+max=([\d.]+)\s+min=([\d.]+)',
        rb_match.group(1)
    )
    if not entries:
        return None

    latest = max(entries, key=lambda e: int(e[0]))
    idx, ts, fps, dur, fmax, fmin = latest
    key = (idx, ts)

    if key == _last_rb_key:
        return None   # same entry as before — don't report

    _last_rb_key = key
    return float(fps), float(fmin), float(fmax)


# ─────────────────────────────────────────────
# Layer name (for display only)
# ─────────────────────────────────────────────
def find_blast_layer(dump):
    m = re.search(
        r'(SurfaceView\[' + re.escape(PACKAGE) + r'[^\]]*\]\(BLAST\)#\d+)',
        dump
    )
    return m.group(1) if m else None


# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────
def main():
    print("=" * 58)
    print("  CODM Real-Time FPS Counter")
    print(f"  Package : {PACKAGE}")
    print("  Mode    : adb shell su -c  |  frame counter diff")
    print("=" * 58)
    print()

    # Check adb
    try:
        result = subprocess.check_output(
            ['adb', 'devices'], stderr=subprocess.DEVNULL
        ).decode()
        devices = [l for l in result.splitlines() if '\tdevice' in l]
        if not devices:
            print("[ERROR] No ADB device connected.")
            sys.exit(1)
        print(f"[OK] Device  : {devices[0].split()[0]}")
    except FileNotFoundError:
        print("[ERROR] 'adb' not found.")
        sys.exit(1)

    # Check root
    su_test = subprocess.run(
        ['adb', 'shell', 'su', '-c', 'id'],
        capture_output=True, text=True, timeout=5
    )
    if 'uid=0' not in su_test.stdout:
        print(f"[WARN] Root check: {su_test.stdout.strip()!r}")
    else:
        print(f"[OK] Root    : {su_test.stdout.strip()}")

    # Initial probe
    print()
    print("[...] Probing SurfaceFlinger...")
    dump = sf_dump()
    if not dump:
        print("[ERROR] dumpsys SurfaceFlinger returned nothing.")
        sys.exit(1)

    layer = find_blast_layer(dump)
    has_rb = bool(re.search(r'FPS ring buffer:', dump))

    if layer:
        print(f"[OK] Layer   : {layer}")
    else:
        print("[WARN] BLAST layer not found — start CODM and enter a match first.")

    print(f"[OK] Source  : frame counter diff" +
          (" + ring buffer min/max" if has_rb else ""))
    print()

    # Warm up: first poll just records the baseline frame count
    dump = sf_dump()
    if dump:
        fps_from_framecounter(dump)   # sets _prev_frame / _prev_time
    time.sleep(POLL_INTERVAL)

    print(f"{'─'*58}")
    print(f"  {'TIME':8}  {'FPS':>6}  {'MIN ft':>8}  {'MAX ft':>8}  BAR")
    print(f"{'─'*58}")

    fps_history = []

    try:
        while True:
            dump = sf_dump()
            fps     = None
            min_ft  = None
            max_ft  = None

            if dump:
                fps = fps_from_framecounter(dump)

                # Enrich with ring buffer min/max if a new entry appeared
                rb = fps_from_ringbuffer(dump)
                if rb:
                    _, min_ft, max_ft = rb

                # Re-detect layer if it changed (match restart)
                new_layer = find_blast_layer(dump)
                if new_layer and new_layer != layer:
                    layer = new_layer
                    print(f"  [Layer updated] -> {layer}")

            ts = time.strftime("%H:%M:%S")

            if fps is not None:
                fps_history.append(fps)
                if len(fps_history) > 60:
                    fps_history.pop(0)

                bar = "█" * min(int(fps / 2), 30)

                min_str = f"{min_ft:7.2f}ms" if min_ft is not None else "    ---  "
                max_str = f"{max_ft:7.2f}ms" if max_ft is not None else "    ---  "

                print(f"  {ts}  {fps:6.1f}  {min_str}  {max_str}  {bar}")
            else:
                print(f"  {ts}    ---   (no frames — in a match?)")

            time.sleep(POLL_INTERVAL)

    except KeyboardInterrupt:
        print()
        print("─" * 58)
        if fps_history:
            # exclude zero-fps entries from stats
            active = [f for f in fps_history if f > 0]
            if active:
                print(f"  Samples : {len(active)}")
                print(f"  Average : {sum(active)/len(active):.1f} FPS")
                print(f"  Min     : {min(active):.1f} FPS")
                print(f"  Max     : {max(active):.1f} FPS")
        print("─" * 58)
        print("  Stopped.")


if __name__ == '__main__':
    main()