#!/system/bin/sh

ui_print ""
ui_print "────────────────────────────────────────"
ui_print "🔰  MODULE INFORMATION"
ui_print "────────────────────────────────────────"
ui_print "• Name       : $(grep_prop name "${TMPDIR}/module.prop")"
sleep 0.2
ui_print "• Version    : $(grep_prop version "${TMPDIR}/module.prop")"
sleep 0.2
ui_print "• Author     : $(grep_prop author "${TMPDIR}/module.prop")"
sleep 0.3
ui_print ""
ui_print "────────────────────────────────────────"
ui_print "📱  DEVICE INFORMATION"
ui_print "────────────────────────────────────────"
ui_print "• Model      : $(getprop ro.product.model)"
sleep 0.2
ui_print "• Board      : $(getprop ro.product.board)"
sleep 0.2
ui_print "• Brand      : $(getprop ro.product.manufacturer)"
sleep 0.2
ui_print "• Android    : $(getprop ro.build.version.release)"
sleep 0.2
ui_print "• Kernel     : $(uname -r)"
sleep 0.2
ui_print "• CPU        : $(getprop ro.hardware)"
sleep 0.2
ui_print "• RAM        : $(free | grep Mem | awk '{print $2}') kB"
sleep 0.4