#!/system/bin/sh
# Lightweight Universal FPS script for Android
# Run with: su -c "sh testfps.sh"

echo "Starting FPS monitor (Press Ctrl+C to stop)..."

get_time_ms() {
    # /proc/uptime usually has two numbers: 1234.56 789.10
    # We multiply the first by 1000 to get milliseconds.
    cat /proc/uptime | awk '{printf "%d", $1 * 1000}'
}

last_frames=0
last_time=$(get_time_ms)

while true; do
    frames=-1
    
    # Try dumpsys first
    res=$(dumpsys SurfaceFlinger 2>/dev/null | grep -E -m 1 'frame-counter=|flips=')
    if [ -n "$res" ]; then
        frames=$(echo "$res" | grep -oE '[0-9]+' | tail -n 1)
    else
        # Fallback to service call
        out=$(service call SurfaceFlinger 1013 2>/dev/null)
        hex=$(echo "$out" | grep -oE 'Parcel\([^ ]+ [0-9a-fA-F]+' | awk '{print $2}')
        if [ -n "$hex" ]; then
            frames=$(printf "%d" 0x$hex)
        fi
    fi

    if [ "$frames" -eq -1 ] || [ -z "$frames" ]; then
        echo "FPS: --"
    else
        current_time=$(get_time_ms)
        
        if [ "$last_frames" -gt 0 ] && [ "$frames" -ge "$last_frames" ]; then
            time_diff=$((current_time - last_time))
            if [ "$time_diff" -gt 0 ]; then
                frame_diff=$((frames - last_frames))
                fps=$((frame_diff * 1000 / time_diff))
                
                # Smooth out exactly 1 frame over-reads
                if [ "$fps" -gt 1 ]; then
                    fps=$((fps - 1))
                fi
                
                # Cap at realistic max
                if [ "$fps" -gt 144 ]; then
                    fps=144
                fi
                
                echo "FPS: $fps"
            fi
        elif [ "$last_frames" -gt 0 ] && [ "$frames" -eq "$last_frames" ]; then
            echo "FPS: 0"
        else
            echo "FPS: -- (Initializing...)"
        fi

        last_frames=$frames
        last_time=$current_time
    fi
    
    sleep 1
done
