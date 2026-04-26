#!/bin/sh

# Clear trash on /data/data @Bias_khaliq
for DIR in /data/data/*; do
  if [ -d "${DIR}" ]; then
    rm -rf ${DIR}/cache/*
    rm -rf ${DIR}/no_backup/*
    rm -rf ${DIR}/app_webview/*
    rm -rf ${DIR}/code_cache/*
  fi
done

# Cache cleaner by Taka, @Kzuyoo, @HoyoSlave
find /data/data/*/cache/* -delete &>/dev/null
find /data/data/*/code_cache/* -delete &>/dev/null
find /data/user_de/*/*/cache/* -delete &>/dev/null
find /data/user_de/*/*/code_cache/* -delete &>/dev/null
find /sdcard/Android/data/*/cache/* -delete &>/dev/null
pm trim-caches 1024G
cmd stats clear-puller-cache
cmd activity clear-debug-app
cmd activity clear-watch-heap -a
cmd activity clear-exit-info
cmd content reset-today-stats
cmd companiondevice refresh-cache
cmd companiondevice remove-inactive-associations
cmd blob_store clear-all-blobs
cmd blob_store clear-all-sessions
cmd device_policy clear-freeze-period-record
wm tracing size 0
cmd font clear
cmd location_time_zone_manager clear_recorded_provider_states
cmd lock_settings remove-cache
cmd media.camera clear-stream-use-case-override
cmd media.camera watch clear
cmd safety_center clear-data
cmd time_detector clear_network_time
cmd time_detector clear_system_clock_network_time
dumpsys procstats --clear
cmd package art cleanup