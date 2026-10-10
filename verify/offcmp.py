# Compare struct-field offsets used by kernel functions: printer kernel (raw binary + kallsyms) vs our vmlinux.
# For each function, collect the multiset of (op, offset) memory accesses relative to non-stack registers
# and report similarity. Config/layout mismatches show up as functions with low similarity.
# Usage: offcmp.py vmlinux.bin kallsyms.txt vmlinux functions.txt [-v] [-all]   (needs $CROSS_COMPILE)
import collections, os, re, subprocess, sys
TC = os.environ['CROSS_COMPILE']
BIN, KALLSYMS, VMLINUX, SYMS = sys.argv[1:5]
BASE = 0x80010000
funcs = [l.strip() for l in open(SYMS) if l.strip()]

def ranges_from(lines):
    syms = []
    for l in lines:
        p = l.split()
        if len(p) >= 3 and p[1] in 'TtWw':
            syms.append((int(p[0], 16), p[2]))
    syms.sort()
    r = {}
    for i, (a, n) in enumerate(syms):
        nxt = next((b for b, _ in syms[i+1:] if b > a), a + 4)
        r.setdefault(n, (a, nxt))
    return r

pr = ranges_from(open(KALLSYMS))
nm = subprocess.run([TC + 'nm', '-n', VMLINUX], capture_output=True, text=True).stdout.splitlines()
mr = ranges_from(nm)
MEM = re.compile(r'\b(lw|sw|lh|lhu|sh|lb|lbu|sb|ll|sc)\s+\$?(\w+),(-?\d+)\(\$?(\w+)\)')

def accesses(args, a, b):
    mode = '-D' if '-b' in args else '-d'
    out = subprocess.run([TC + 'objdump', mode, '--no-show-raw-insn', '-M', 'no-aliases,gpr-names=32',
                          '--start-address=0x%x' % a, '--stop-address=0x%x' % b] + args,
                         capture_output=True, text=True).stdout
    c = collections.Counter()
    for m in MEM.finditer(out):
        op, _, off, base = m.groups()
        if base in ('29', 'sp', '28', 'gp', '30', 'fp', 's8'):
            continue
        c[(op, int(off))] += 1
    return c

rawargs = ['-b', 'binary', '-m', 'mips:isa32r2', '-EL', '--adjust-vma=0x%x' % BASE, BIN]
rows = []
for f in funcs:
    if f not in pr or f not in mr:
        continue
    a = accesses(rawargs, *pr[f])
    b = accesses([VMLINUX], *mr[f])
    if not a and not b:
        continue
    inter = sum((a & b).values()); union = sum((a | b).values())
    rows.append((inter / union if union else 1.0, f, a, b))
rows.sort()
for sim, f, a, b in rows:
    flag = '  <<' if sim < 0.6 or '-all' in sys.argv else ''
    print('%.2f %-40s printer=%d ours=%d%s' % (sim, f, sum(a.values()), sum(b.values()), flag))
    if flag and '-v' in sys.argv:
        print('     only printer:', sorted((a - b).items())[:25])
        print('     only ours:   ', sorted((b - a).items())[:25])
print('checked', len(rows), 'functions; mean similarity %.2f' % (sum(r[0] for r in rows) / max(1, len(rows))))
