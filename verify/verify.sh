#!/bin/bash
# Check a build of the modules against a printer's kernel (run kernel/build.sh and
# verify/collect-printer.sh first). Prints anything that does not line up.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=${WORK:-$(cd "$HERE/.." && pwd)/work}
K=$WORK/linux-5.10.186
P=$WORK/printer
export CROSS_COMPILE=${CROSS_COMPILE:-$WORK/mips32el--glibc--stable-2023.08-1/bin/mipsel-linux-}
TC=$CROSS_COMPILE

section_size() { "${TC}readelf" -SW "$1" | awk -v s="$2" '$2==s{print $6} $3==s{print $7}' | head -1; }

echo "== vermagic"
for f in "$WORK/dist/r8152.ko" "$WORK/dist/mii.ko" "$P/cp210x.ko"; do
	printf '  %-12s %s\n' "$(basename "$f")" "$("${TC}strings" "$f" | grep ^vermagic=)"
done

echo "== module format vs Z-Mod's cp210x.ko / usbserial.ko (same source, built by Z-Mod for this kernel)"
for m in cp210x usbserial; do
	ours=$(find "$K/drivers/usb/serial" -name "$m.ko")
	for s in .gnu.linkonce.this_module __dyndbg; do
		printf '  %-10s %-26s z-mod=%-7s ours=%s\n' "$m" "$s" "$(section_size "$P/$m.ko" $s)" "$(section_size "$ours" $s)"
	done
done
echo "  (struct module must match exactly; __dyndbg must be a multiple of 24 bytes)"

echo "== imported symbols missing from the printer's exports"
"${TC}nm" -u "$K/drivers/net/usb/r8152.ko" "$K/drivers/net/mii.ko" | awk 'NF {print $NF}' | grep -v ':' | sort -u > "$WORK/imports.txt"
missing=0
while read -r s; do
	grep -qw "$s" "$P/exports.txt" || "${TC}nm" "$K/drivers/net/mii.ko" | grep -q " T $s\$" || { echo "  $s"; missing=1; }
done < "$WORK/imports.txt"
[ $missing -eq 0 ] && echo "  none"

echo "== struct offset differences (ours -> printer) in imported and core functions"
echo "   lw/sw pairs with |offset| in the thousands are global-variable addresses, not struct fields"
cat "$WORK/imports.txt" "$HERE/functions.txt" | sort -u > "$WORK/compare.txt"
python3 -I "$HERE/aligncmp.py" "$P/vmlinux.bin" "$P/kallsyms.txt" "$K/vmlinux" "$WORK/compare.txt"
