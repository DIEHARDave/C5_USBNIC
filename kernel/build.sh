#!/bin/bash
# Build r8152.ko and mii.ko for the Flashforge Creator 5 Pro vendor kernel (5.10.186+, MIPS32r5 LE).
# Run on Linux (or WSL). Downloads the Bootlin toolchain and Linux 5.10.186 into $WORK on first use.
# Output: $WORK/dist/{r8152,mii}.ko
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=${WORK:-$(cd "$HERE/.." && pwd)/work}
KVER=5.10.186
TC=mips32el--glibc--stable-2023.08-1
TC_URL=https://toolchains.bootlin.com/downloads/releases/toolchains/mips32el/tarballs/$TC.tar.bz2
VERMAGIC="5.10.186+ SMP preempt mod_unload MIPS32_R5 32BIT "

mkdir -p "$WORK"
cd "$WORK"
if [ ! -d "$TC" ]; then
	wget -q "$TC_URL"
	tar xjf "$TC.tar.bz2"
fi
if [ ! -d "linux-$KVER" ]; then
	wget -q "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$KVER.tar.xz"
	tar xJf "linux-$KVER.tar.xz"
	for p in "$HERE"/patches/*.patch; do
		patch -d "linux-$KVER" -p1 < "$p"
	done
fi

export ARCH=mips CROSS_COMPILE="$WORK/$TC/bin/mipsel-linux-"
cd "linux-$KVER"
make -s malta_defconfig
scripts/kconfig/merge_config.sh -m .config "$HERE/cc5.config" >/dev/null
make -s olddefconfig
sed -i 's/^CONFIG_LOCALVERSION_AUTO=.*/# CONFIG_LOCALVERSION_AUTO is not set/' .config

# Every option in the fragment must have survived Kconfig dependency resolution
bad=0
while IFS= read -r line; do
	case "$line" in
	CONFIG_*=*)
		grep -qx "$line" .config || { echo "config mismatch: want $line, have: $(grep "^${line%%=*}=" .config || echo unset)"; bad=1; } ;;
	"# CONFIG_"*" is not set")
		o=${line#\# }; o=${o%% *}
		grep -q "^$o=" .config && { echo "config mismatch: want $o unset"; bad=1; } ;;
	esac
done < "$HERE/cc5.config"
[ $bad -eq 0 ] || exit 1

# vmlinux is only needed by the verification tools; it costs a few minutes
make -j"$(nproc)" vmlinux modules > "$WORK/build.log" 2>&1 || { tail -30 "$WORK/build.log"; exit 1; }

mkdir -p "$WORK/dist"
for m in drivers/net/usb/r8152.ko drivers/net/mii.ko; do
	"${CROSS_COMPILE}strip" --strip-debug -o "$WORK/dist/$(basename $m)" "$m"
	vm=$("${CROSS_COMPILE}strings" "$WORK/dist/$(basename $m)" | sed -n 's/^vermagic=//p')
	[ "$vm" = "$VERMAGIC" ] || { echo "unexpected vermagic for $m: '$vm'"; exit 1; }
done
cd "$WORK/dist"
sha256sum r8152.ko mii.ko
echo "Built modules are in $WORK/dist"
