#!/bin/sh
# udhcpc event script for the USB Ethernet adapter: address, default route and DNS.
# DNS entries are tagged "# eth0" and added alongside the Wi-Fi ones, never replacing them.

METRIC=10
RESOLV=/tmp/resolv.conf		# /etc/resolv.conf links here

update_dns()
{
	tmp=$RESOLV.eth0.$$
	{
		if [ -n "$1" ]; then
			[ -n "$domain" ] && echo "search $domain # $interface"
			for ns in $dns; do echo "nameserver $ns # $interface"; done
		fi
		grep -v "# $interface\$" "$RESOLV" 2>/dev/null
	} > "$tmp"
	cat "$tmp" > "$RESOLV"
	rm -f "$tmp"
}

case "$1" in
	deconfig)
		ip -4 addr flush dev "$interface"
		ip link set "$interface" up
		update_dns
		;;
	bound|renew)
		if ! ip -4 addr show dev "$interface" | grep -q "inet $ip/$mask "; then
			ip -4 addr flush dev "$interface"
			ip addr add "$ip/$mask" ${broadcast:+broadcast $broadcast} dev "$interface"
		fi
		while ip route del default dev "$interface" 2>/dev/null; do :; done
		for r in $router; do
			ip route add default via "$r" dev "$interface" metric $METRIC
		done
		update_dns 1
		echo "$(date) $1: $ip/$mask router=$router dns=$dns"
		;;
	leasefail|nak)
		echo "$(date) $1"
		;;
esac
exit 0
