if [ -f $INFO ]; then
  while read LINE; do
    if [ "$(echo -n $LINE | tail -c 1)" == "~" ]; then
      continue
    elif [ -f "$LINE~" ]; then
      mv -f $LINE~ $LINE
    else
      rm -f $LINE
      while true; do
        LINE=$(dirname $LINE)
        [ "$(ls -A $LINE 2>/dev/null)" ] && break 1 || rm -rf $LINE
      done
    fi
  done < $INFO
  rm -f $INFO
fi

resetprop net.dns1 ""
resetprop net.dns2 ""
for iface in rmnet0 rmnet1 net wcdma hspa lte ltea ppp0 pdpbr1 wlan0; do
    resetprop net.$iface.dns1 ""
    resetprop net.$iface.dns2 ""
done
for svc in tcpdump vendor.tcpdump cnss_diag vendor.cnss_diag; do
    start "$svc" 2>/dev/null
done
settings put global private_dns_mode off
settings delete global private_dns_specifier