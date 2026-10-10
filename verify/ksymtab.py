# Parse exported symbols (__ksymtab entries: u32 value, u32 name_ptr, u32 ns_ptr; LE) from a raw MIPS vmlinux.bin
import sys, struct, re
data = open(sys.argv[1], 'rb').read()
base = int(sys.argv[2], 16)
n = len(data)
def cstr(addr):
    o = addr - base
    if not (0 <= o < n): return None
    e = data.find(b'\0', o, o + 128)
    if e <= o: return None
    s = data[o:e]
    return s.decode() if re.fullmatch(rb'[A-Za-z_][A-Za-z0-9_.$]*', s) else None
runs = []
for start in range(0, 12, 4):
    i = start; run = []
    while i + 12 <= n:
        v, np_ = struct.unpack_from('<II', data, i)
        name = cstr(np_) if 0x80000000 <= v < 0x90000000 else None
        if name:
            run.append((v, name))
        else:
            if len(run) > 100: runs.append(run)
            run = []
        i += 12
    if len(run) > 100: runs.append(run)
seen = set()
for run in runs:
    for v, name in run:
        if name not in seen:
            seen.add(name); print('%08x %s' % (v, name))
