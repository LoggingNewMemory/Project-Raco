###################################
# Star Tweak (@Koneko_dev)
# Version amba 2.0 
# Note: 
###################################

setprop debug.hwui.target_cpu_time_percent 65
setprop debug.hwui.use_hint_manager true
setprop debug.sf.enable_adpf_cpu_hint true

maincore () {
atrace --async_stop 1>/dev/null
cmd looper_stats reset;cmd looper_stats disable
for app in $(pm list packages | cut -d: -f2); do pm log-visibility --disable $app; done &
for a in --reset --disable --disable-detailed-tracking;do dumpsys binder_calls_stats $a;done
for b in --clear --stop-testing; do dumpsys procstats $b;done
for c in ab-logging-disable dwb-logging-disable dmd-logging-disable; do cmd display $c;done
for f in $(dumpsys window | grep "^  Proto:" | sed 's/^  Proto: //' | tr ' ' '\n'; dumpsys window | grep "^  Logcat:" | sed 's/^  Logcat: //' | tr ' ' '\n'); do wm logging disable "$f"; wm logging disable-text "$f"; done
}


#trigger action
maincore