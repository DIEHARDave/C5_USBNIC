#!/bin/bash
# Install the RTL8153 USB Ethernet driver and boot-time DHCP on a Creator 5 Pro running Z-Mod.
# Usage: printer/install.sh root@PRINTER_IP [MODULE_DIR]
#   MODULE_DIR defaults to prebuilt/ (use work/dist after building your own)
set -euo pipefail

HOST=$1
HERE=$(cd "$(dirname "$0")" && pwd)
MODS=${2:-$HERE/../prebuilt}
FW=rtl8153b-2.fw
FW_URL=https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/rtl_nic/$FW

kver=$(ssh "$HOST" uname -r)
if [ "$kver" != "5.10.186+" ]; then
	echo "Printer kernel is '$kver'; these modules only fit 5.10.186+. Rebuild and verify first." >&2
	exit 1
fi
ssh "$HOST" test -f /opt/config/mod_data/variables.cfg || { echo "Z-Mod not found on the printer" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -sSfL -o "$tmp/$FW" "$FW_URL"

ssh "$HOST" mkdir -p /usr/data/r8152/firmware/rtl_nic
scp -O "$MODS/mii.ko" "$MODS/r8152.ko" "$HERE/eth-up.sh" "$HERE/udhcpc-eth0.sh" "$HOST:/usr/data/r8152/"
scp -O "$tmp/$FW" "$HOST:/usr/data/r8152/firmware/rtl_nic/"

# Z-Mod runs /opt/config/mod_data/power_on.sh (outside its chroot) late in every boot
ssh "$HOST" 'chmod +x /usr/data/r8152/*.sh
P=/opt/config/mod_data/power_on.sh
[ -f $P ] || printf "#!/bin/sh\n" > $P
chmod +x $P
grep -q "r8152/eth-up.sh" $P || echo "/usr/data/r8152/eth-up.sh &" >> $P
sync'

echo "Installed. It starts on the next boot; to start it now:"
echo "  ssh $HOST '/usr/data/r8152/eth-up.sh </dev/null >/dev/null 2>&1 &'"
