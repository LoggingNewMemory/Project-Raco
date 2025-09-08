for pkg in $(pm list packages -3 | cut -f 2 -d ":"); do
    if [ "$pkg" != "com.google.android.inputmethod.latin" ]; then
        am force-stop $pkg
    fi
done

echo 3 > /proc/sys/vm/drop_caches
am kill-all
