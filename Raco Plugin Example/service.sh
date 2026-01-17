#!/system/bin/sh

apply() {
    for cmd in "$@"; do
        eval "$cmd" >/dev/null 2>&1
    done
}

apply \
"echo '4096' > /proc/sys/net/core/netdev_max_backlog" \
"echo '262144' > /proc/sys/net/core/rmem_default" \
"echo '524288' > /proc/sys/net/core/rmem_max" \
"echo '262144' > /proc/sys/net/core/wmem_default" \
"echo '524288' > /proc/sys/net/core/wmem_max" \
"echo '4096' > /proc/sys/net/core/somaxconn" \
"echo '204800' > /proc/sys/net/core/optmem_max" \
"echo '0' > /proc/sys/net/ipv4/tcp_slow_start_after_idle" \
"echo '1' > /proc/sys/net/ipv4/tcp_low_latency" \
"echo '1' > /proc/sys/net/ipv4/tcp_timestamps" \
"echo '1' > /proc/sys/net/ipv4/tcp_sack" \
"echo '1' > /proc/sys/net/ipv4/tcp_fack" \
"echo '1' > /proc/sys/net/ipv4/tcp_window_scaling" \
"echo '1' > /proc/sys/net/ipv4/tcp_moderate_rcvbuf" \
"echo '0' > /proc/sys/net/ipv4/tcp_no_metrics_save" \
"echo '3' > /proc/sys/net/ipv4/tcp_syn_retries" \
"echo '2' > /proc/sys/net/ipv4/tcp_synack_retries" \
"echo '3' > /proc/sys/net/ipv4/tcp_retries2" \
"echo '15' > /proc/sys/net/ipv4/tcp_fin_timeout" \
"echo '4096 87380 524288' > /proc/sys/net/ipv4/tcp_rmem" \
"echo '4096 65536 524288' > /proc/sys/net/ipv4/tcp_wmem" \
"echo '8192' > /proc/sys/net/ipv4/udp_rmem_min" \
"echo '8192' > /proc/sys/net/ipv4/udp_wmem_min" \
"echo '1' > /proc/sys/net/ipv4/tcp_tw_reuse" \
"echo '262144' > /proc/sys/net/ipv4/tcp_max_tw_buckets" \
"echo '8192' > /proc/sys/net/ipv4/tcp_max_syn_backlog" \
"echo '1' > /proc/sys/net/ipv4/tcp_fastopen" \
"echo '1024' > /proc/sys/net/ipv4/neigh/default/gc_thresh1" \
"echo '2048' > /proc/sys/net/ipv4/neigh/default/gc_thresh2" \
"echo '4096' > /proc/sys/net/ipv4/neigh/default/gc_thresh3" \
"echo '0' > /proc/sys/net/ipv6/neigh/default/anycast_delay" \
"echo '0' > /proc/sys/net/ipv6/neigh/default/delay_first_probe_time" \
"echo '0' > /proc/sys/net/ipv6/neigh/default/proxy_delay" \
"echo '0' > /proc/sys/net/ipv6/conf/all/router_solicitation_delay" \
"echo '0' > /proc/sys/net/ipv6/conf/default/router_solicitation_delay" \
"echo '0' > /proc/sys/net/ipv4/conf/all/rp_filter" \
"echo '0' > /proc/sys/net/ipv4/icmp_echo_ignore_all" \
"echo '1' > /proc/sys/net/ipv4/route/flush"

cmd notification post -S bigtext -t 'PingPimp' 'Tag' 'Default Applied'

exit 0