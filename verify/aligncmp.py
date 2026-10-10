# Align each function's instruction stream (printer vs ours) by opcode and report memory-operand offset
# differences as (ours -> printer) pairs. Pairs with a large immediate (>= 0x2000) are global-address
# low halves, not struct fields, and are skipped.
# Usage: aligncmp.py vmlinux.bin kallsyms.txt vmlinux functions.txt [-v] [-a]   (needs $CROSS_COMPILE)
import collections, difflib, os, re, subprocess, sys
TC = os.environ['CROSS_COMPILE']
BIN, KALLSYMS, VMLINUX, SYMS = sys.argv[1:5]
# Load address of the printer's raw kernel image (_stext is 0x80010400)
BASE = 0x80010000
funcs = [l.strip() for l in open(SYMS) if l.strip()]

def ranges(lines):
    syms = sorted((int(p[0], 16) & 0xffffffff, p[2]) for p in (l.split() for l in lines)
                  if len(p) >= 3 and p[1] in 'TtWw')
    r = {}
    for i, (a, n) in enumerate(syms):
        nxt = next((b for b, _ in syms[i + 1:] if b > a), a + 4)
        r.setdefault(n, (a, nxt))
    return r

pr = ranges(open(KALLSYMS))
mr = ranges(subprocess.run([TC + 'nm', VMLINUX], capture_output=True, text=True).stdout.splitlines())
INS = re.compile(r'^\s*[0-9a-f]+:\s+(\S+)\s*(.*)$')
MEM = re.compile(r'(-?\d+)\((\w+)\)')

def dis(args, a, b):
    mode = '-D' if '-b' in args else '-d'
    out = subprocess.run([TC + 'objdump', mode, '--no-show-raw-insn', '--start-address=0x%x' % a,
                          '--stop-address=0x%x' % b] + args, capture_output=True, text=True).stdout
    res = []
    for l in out.splitlines():
        m = INS.match(l)
        if m and m.group(1) != 'nop':
            res.append((m.group(1), m.group(2)))
    return res

raw = ['-b', 'binary', '-m', 'mips:isa32r2', '-EL', '--adjust-vma=0x%x' % BASE, BIN]
allpairs = collections.Counter()
for f in funcs:
    if f not in pr or f not in mr:
        continue
    p = dis(raw, *pr[f]); o = dis([VMLINUX], *mr[f])
    sm = difflib.SequenceMatcher(None, [x[0] for x in o], [x[0] for x in p], autojunk=False)
    pairs = collections.Counter()
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag != 'equal':
            continue
        for k in range(i2 - i1):
            mo = MEM.search(o[i1 + k][1]); mp = MEM.search(p[j1 + k][1])
            if mo and mp and mo.group(2) not in ('sp', 'gp') and mo.group(1) != mp.group(1):
                a, b = int(mo.group(1)), int(mp.group(1))
                if abs(a) < 0x2000 and abs(b) < 0x2000:
                    pairs[(o[i1 + k][0], a, b)] += 1
                    if '-v' in sys.argv:
                        ctx = lambda s, i: ' ; '.join('%s %s' % x for x in s[max(0, i - 3):i + 1])
                        print('   %s: ours[%s]\n   %s  prn[%s]' % (f, ctx(o, i1 + k), ' ' * len(f), ctx(p, j1 + k)))
    if pairs or '-a' in sys.argv:
        print('%-36s ratio=%.2f  %s' % (f, sm.ratio(), ' '.join('%s:%d->%d' % k for k in sorted(pairs))))
    allpairs.update({(a, b): n for (op, a, b), n in pairs.items()})
