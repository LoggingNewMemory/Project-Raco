#!/system/bin/sh

CONF="/data/misc/wifi/wpa_supplicant.conf"
FACE="lo wlan0 rmnet_data0 rmnet_ipa0 dummy0 rmnet0 rndis0"
while [ ! -f "$CONF" ]; do
    sleep 2
done
grep -q "p2p_disabled=1" "$CONF" || echo "p2p_disabled=1" >> "$CONF"
grep -q "ap_scan=1" "$CONF" || echo "ap_scan=1" >> "$CONF"
if command -v iw >/dev/null 2>&1; then
    iw wlan0 set power_save off 2>/dev/null
    iw wlan0 set txpower fixed 2000 2>/dev/null
fi
for iface in $FACE; do
    if [ -d "/sys/class/net/$iface" ]; then
        if command -v tc >/dev/null 2>&1; then
            tc qdisc del dev "$iface" root 2>/dev/null
            tc qdisc add dev "$iface" root fq_codel 2>/dev/null
        fi
        case "$iface" in
            lo|dummy0) QUEUE=100 ;;
            wlan0) QUEUE=1200 ;;
            rmnet_data0|rmnet_ipa0|rmnet0|rndis0) QUEUE=1500 ;;
            usb0|eth0) QUEUE=2000 ;;
            *) QUEUE=1000 ;;
        esac
        ifconfig "$iface" txqueuelen "$QUEUE" 2>/dev/null
    fi
done
ip route flush cache 2>/dev/null
cmd wifi force-low-latency-mode enabled
for svc in tcpdump vendor.tcpdump cnss_diag vendor.cnss_diag; do
    stop "$svc" 2>/dev/null
done
if [ -d /data/vendor/wlan_logs ]; then
    rm -rf /data/vendor/wlan_logs
    mkdir /data/vendor/wlan_logs
    chmod 000 /data/vendor/wlan_logs
fi