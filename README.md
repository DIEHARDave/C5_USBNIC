# C5_USBNIC

Wired Ethernet for the **Flashforge Creator 5 Pro** through a USB 3 gigabit adapter based on the
Realtek **RTL8153** (USB ID `0bda:8153`), using the mainline `r8152` driver built for the printer's
vendor kernel. Wi-Fi keeps working alongside it.

Tested on a Creator 5 Pro running Z-Mod 1.7.4 with HelixScreen: gigabit link, DHCP at boot,
50 MB each way with no errors, Wi-Fi failover in both directions.

## Requirements

- Creator 5 Pro whose kernel reports `uname -r` = `5.10.186+` (Ingenic X2600, MIPS32r5 LE)
- [Z-Mod](https://github.com/ghzserg/zmod) installed (its `power_on.sh` hook starts the driver at boot)
- SSH access as root. The printer runs Dropbear 2019.78, which does not accept ed25519 keys; use
  `ssh-keygen -t ecdsa` or RSA.
- An RTL8153-based adapter. The bundled firmware patch is for the RTL8153B; other chip
  revisions work without a patch, or add theirs from linux-firmware.

## Install

From Linux or WSL:

```bash
printer/install.sh root@PRINTER_IP
```

This checks the printer's kernel version, copies `prebuilt/{mii,r8152}.ko`, the startup scripts and
the `rtl8153b-2.fw` firmware patch (downloaded from linux-firmware) to `/usr/data/r8152/`, and adds
one line to `/opt/config/mod_data/power_on.sh`. Reboot, or start it right away with the command the
script prints. `printer/uninstall.sh root@PRINTER_IP` reverses it.

Log: `/usr/data/r8152/eth-up.log` on the printer.

## How it behaves

- `eth0` gets an address by DHCP (busybox `udhcpc`; the stock `dhcpcd` 8.0.3 segfaults on it).
- Ethernet is preferred while its cable is connected: its default route has metric 10 and the
  Wi-Fi routes are moved to metric 300.
- `ignore_routes_with_linkdown` is enabled, so turning Wi-Fi off (HelixScreen sends
  `DISABLE_NETWORK all` to wpa_supplicant) or unplugging the cable falls back to the other link
  instead of sending traffic into a dead one.
- `arp_ignore=1` / `arp_announce=2`: each address is only answered on its own interface, so the Wi-Fi
  address is unreachable while Wi-Fi is off. Give the adapter a DHCP reservation for a fixed address.
- DNS servers from both links are kept in `/etc/resolv.conf`; Ethernet's are tagged `# eth0`.

## Building the modules yourself

Flashforge does not publish the kernel source or config, so the modules are built from
vanilla Linux 5.10.186 with a configuration and two small header/Kconfig patches that reproduce
the vendor kernel's struct layouts:

```bash
kernel/build.sh               # downloads the Bootlin GCC 12.3 toolchain and the kernel into ./work
```

Output goes to `work/dist/`. Install it with `printer/install.sh root@PRINTER_IP work/dist`.

If a Flashforge firmware update changes the kernel, the modules must be rebuilt **and re-verified**.

## Verification

A module built against the wrong struct layouts loads fine and then corrupts kernel memory, so the
build was checked against the printer's own kernel:

```bash
verify/collect-printer.sh root@PRINTER_IP   # kallsyms, running kernel image, Z-Mod's cp210x/usbserial
verify/verify.sh
```

- **Module format**: `struct module` (0x180 bytes) and `struct _ddebug` (24 bytes) match Z-Mod's
  `cp210x.ko`/`usbserial.ko`, which were built for this kernel.
- **Imports**: every kernel symbol the modules need is exported by the printer kernel.
- **Struct layouts**: `aligncmp.py` disassembles each function the driver calls (and the USB/net core
  functions that call back into it) from both the printer kernel and this build, aligns the
  instruction streams, and reports every memory-operand offset that differs.

Differences found and fixed this way, relative to `malta_defconfig`:

| Symptom in the printer's code | Cause |
| --- | --- |
| `sk_buff->tail` 8, then 4 bytes earlier | `XFRM`/`SKB_EXTENSIONS`, `NETWORK_SECMARK`, `NET_SCHED` off |
| `net_device` fields 8 + 4 bytes earlier | `WIRELESS_EXT`, `ATALK` off |
| `net_device->broadcast` 4 bytes later | `NETFILTER_INGRESS` on |
| `netdev_queue` 192 instead of 256 bytes | 32-byte L1 cache lines (patch 0002) |
| `net_device->dev` at 696, not 704 | `NET_NS` off |
| `usb_device->parent` and everything after +4 | vendor field after `tx_lanes` (patch 0001) |
| dynamic-debug checks read the flags word directly | `JUMP_LABEL` off |

What remains in `verify.sh` output is global-variable addresses, instruction scheduling between
GCC 7 (vendor) and GCC 12, and one later upstream USB fix the vendor kernel lacks; none of it
touches fields the driver uses.

`verify/probe-offsets.sh` prints this build's struct offsets for reading the comparison output.

## Repository layout

```
kernel/    cc5.config (config fragment), patches/, build.sh
verify/    collect-printer.sh, verify.sh, aligncmp.py, offcmp.py, ksymtab.py, probe/
printer/   eth-up.sh (boot script), udhcpc-eth0.sh (DHCP hook), install.sh, uninstall.sh
prebuilt/  r8152.ko, mii.ko, SHA256SUMS
```

## Notes

- On every boot Z-Mod's camera script runs `v4l2-ctl` against `/dev/video2` (the X2600 H.264
  decoder), which oopses in the vendor `dma_coherent_mem_available()`. It happens without this
  driver too and is unrelated.
- Use at your own risk; this modifies a printer that has heaters and moving parts. Load new builds
  only while the printer is idle.

## License

GPL-2.0, like the Linux kernel the modules and patches come from. The RTL8153B firmware is not
included; `install.sh` downloads it from linux-firmware, which carries its own license.
