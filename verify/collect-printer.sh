#!/bin/bash
# Copy what the verification needs from a printer: kallsyms, the running kernel image and
# Z-Mod's own serial modules (a known-good reference built for this kernel).
# Usage: verify/collect-printer.sh root@PRINTER_IP      (key-based SSH; Dropbear 2019 needs an ECDSA/RSA key)
set -euo pipefail

HOST=$1
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${WORK:-$(cd "$HERE/.." && pwd)/work}/printer
mkdir -p "$OUT"

ssh "$HOST" cat /proc/kallsyms > "$OUT/kallsyms.txt"

# The active kernel partition pairs with the active root: p1/p2 or p3/p4
root=$(ssh "$HOST" cat /proc/cmdline | sed -n 's/.*root=\([^ ]*\).*/\1/p')
case "$root" in
	*mmcblk0p2) part=mmcblk0p1 ;;
	*mmcblk0p4) part=mmcblk0p3 ;;
	*) echo "unexpected root device '$root'"; exit 1 ;;
esac
ssh "$HOST" "dd if=/dev/$part bs=1M 2>/dev/null" > "$OUT/kernel.img"
scp -O "$HOST:/usr/data/zmod/zmod/.shell/serial/cp210x.ko" "$HOST:/usr/data/zmod/zmod/.shell/serial/usbserial.ko" "$OUT/"

# uImage with a gzip-compressed payload; decompress the raw kernel (trailing data is expected)
off=$(grep -obUaP '\x1f\x8b\x08' "$OUT/kernel.img" | head -1 | cut -d: -f1)
tail -c +$((off + 1)) "$OUT/kernel.img" | gzip -dc > "$OUT/vmlinux.bin" 2>/dev/null || true
python3 -I "$HERE/ksymtab.py" "$OUT/vmlinux.bin" 80010000 > "$OUT/exports.txt"

echo "kallsyms: $(wc -l < "$OUT/kallsyms.txt") symbols, exports: $(wc -l < "$OUT/exports.txt"), vmlinux.bin: $(stat -c %s "$OUT/vmlinux.bin") bytes"
