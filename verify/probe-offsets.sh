#!/bin/bash
# Print struct sizes/offsets of this build (handy for reading aligncmp.py output)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=${WORK:-$(cd "$HERE/.." && pwd)/work}
export ARCH=mips CROSS_COMPILE=${CROSS_COMPILE:-$WORK/mips32el--glibc--stable-2023.08-1/bin/mipsel-linux-}
B=$WORK/probe
rm -rf "$B" && mkdir -p "$B" && cp "$HERE/probe/probe.c" "$B/" && echo 'obj-m := probe.o' > "$B/Makefile"
make -s -C "$WORK/linux-5.10.186" M="$B" probe.s
grep -o '@@ [^"]*' "$B/probe.s" | sed 's/@@ //' | column -t
