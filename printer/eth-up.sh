#!/bin/sh
# Bring up the RTL8153 USB Ethernet adapter (eth0) with DHCP, alongside Wi-Fi.
# Started in the background at boot from /opt/config/mod_data/power_on.sh (Z-Mod user hook).
#
# - Ethernet is preferred while its cable is connected (route metric 10 vs 300 for Wi-Fi).
# - Routes on an interface without link are ignored, so turning Wi-Fi off (or unplugging
#   the cable) falls back to the other interface instead of black-holing traffic.

DIR=/usr/data/r8152
LOG=$DIR/eth-up.log
WLAN_METRIC=300

[ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 65536 ] && mv "$LOG" "$LOG.old"
exec >>"$LOG" 2>&1
echo "=== $(date) eth-up start"

# Firmware patch rtl_nic/rtl8153b-2.fw is kept under $DIR/firmware
printf %s "$DIR/firmware" > /sys/module/firmware_class/parameters/path

grep -q '^mii ' /proc/modules || insmod "$DIR/mii.ko" || exit 1
grep -q '^r8152 ' /proc/modules || insmod "$DIR/r8152.ko" || exit 1

# Multi-homed on one subnet: skip routes without link, keep ARP replies per interface
echo 1 > /proc/sys/net/ipv4/conf/all/ignore_routes_with_linkdown
echo 1 > /proc/sys/net/ipv4/conf/all/arp_ignore
echo 2 > /proc/sys/net/ipv4/conf/all/arp_announce

i=0
while [ ! -e /sys/class/net/eth0 ] && [ $i -lt 30 ]; do sleep 1; i=$((i + 1)); done
if [ ! -e /sys/class/net/eth0 ]; then
	echo "eth0 did not appear (adapter unplugged?)"
	exit 1
fi

ip link set eth0 up
PIDFILE=/var/run/udhcpc.eth0.pid
if [ -f $PIDFILE ] && kill -0 "$(cat $PIDFILE)" 2>/dev/null; then
	echo "udhcpc already running for eth0"
else
	# The stock dhcpcd 8.0.3 segfaults on this interface; busybox udhcpc keeps the lease renewed
	udhcpc -i eth0 -b -R -p $PIDFILE -s "$DIR/udhcpc-eth0.sh" -x hostname:"$(hostname)"
fi

# Wi-Fi routes are added with metric 0 by the stock network setup; move them behind Ethernet.
# Re-checked every minute in case Wi-Fi is reconnected and its routes are re-added.
deprioritize_wlan()
{
	ip -4 route show dev wlan0 2>/dev/null | grep -v ' metric ' | while read -r route; do
		ip route del $route dev wlan0 && ip route add $route dev wlan0 metric $WLAN_METRIC &&
			echo "$(date) wlan0 route '$route' -> metric $WLAN_METRIC"
	done
}

while true; do
	deprioritize_wlan
	sleep 60
done
