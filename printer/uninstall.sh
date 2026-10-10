#!/bin/bash
# Remove the USB Ethernet setup from the printer. Takes full effect after a reboot.
# Usage: printer/uninstall.sh root@PRINTER_IP
set -euo pipefail

ssh "$1" 'sed -i "/r8152\/eth-up.sh/d" /opt/config/mod_data/power_on.sh
kill $(pidof eth-up.sh) 2>/dev/null
[ -f /var/run/udhcpc.eth0.pid ] && kill $(cat /var/run/udhcpc.eth0.pid) 2>/dev/null
rm -rf /usr/data/r8152
sync
echo "Removed. Reboot the printer to unload the driver and restore the original Wi-Fi routes."'
