#!/system/bin/sh

grep_prop() {
  grep "^$1=" "$2" | head -n 1 | cut -d= -f2-
}

echo ""
echo "────────────────────────────────────────"
echo "🔰  MODULE INFORMATION"
echo "────────────────────────────────────────"
echo "• Name       : $(grep_prop name "./raco.prop")"
sleep 0.2
echo "• Version    : $(grep_prop version "./raco.prop")"
sleep 0.2
echo "• Author     : $(grep_prop author "./raco.prop")"
sleep 0.3
echo ""
echo "────────────────────────────────────────"
echo "📱  DEVICE INFORMATION"
echo "────────────────────────────────────────"
echo "• Model      : $(getprop ro.product.model)"
sleep 0.2
echo "• Board      : $(getprop ro.product.board)"
sleep 0.2
echo "• Brand      : $(getprop ro.product.manufacturer)"
sleep 0.2
echo "• Android    : $(getprop ro.build.version.release)"
sleep 0.2
echo "• Kernel     : $(uname -r)"
sleep 0.2
echo "• CPU        : $(getprop ro.hardware)"
sleep 0.2
echo "• RAM        : $(free | grep Mem | awk '{print $2}') kB"
sleep 0.4