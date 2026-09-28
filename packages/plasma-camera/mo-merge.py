#!/usr/bin/python3
# Добавить переводы из .po в готовый .mo: mo-merge.py старый.mo дополнение.po новый.mo
import re, struct, sys
def read_mo(p):
    d = open(p, 'rb').read()
    _, _, n, oo, ot = struct.unpack('<5I', d[:20])
    cat = {}
    for i in range(n):
        l, o = struct.unpack('<2I', d[oo + 8 * i:oo + 8 * i + 8])
        l2, o2 = struct.unpack('<2I', d[ot + 8 * i:ot + 8 * i + 8])
        cat[d[o:o + l]] = d[o2:o2 + l2]
    return cat
def read_po(p):
    cat, key, cur, field = {}, None, None, None
    def s(x): return eval(x.strip())
    for line in open(p, encoding='utf-8'):
        line = line.strip()
        if line.startswith('msgid '): key, field = s(line[6:]), 'id'
        elif line.startswith('msgstr '):
            cur, field = s(line[7:]), 'str'
        elif line.startswith('"'):
            if field == 'id': key += s(line)
            elif field == 'str': cur += s(line)
        elif not line and key is not None and cur is not None:
            if key: cat[key.encode()] = cur.encode()
            key = cur = None
    if key and cur is not None: cat[key.encode()] = cur.encode()
    return cat
cat = read_mo(sys.argv[1]); cat.update(read_po(sys.argv[2]))
keys = sorted(cat)
ids = b''.join(k + b'\0' for k in keys); strs = b''.join(cat[k] + b'\0' for k in keys)
n = len(keys); oo = 28; ot = oo + 8 * n; start = ot + 8 * n
out = struct.pack('<7I', 0x950412de, 0, n, oo, ot, 0, 0)
off, tab_o = start, b''
for k in keys: tab_o += struct.pack('<2I', len(k), off); off += len(k) + 1
off2, tab_t = start + len(ids), b''
for k in keys: tab_t += struct.pack('<2I', len(cat[k]), off2); off2 += len(cat[k]) + 1
open(sys.argv[3], 'wb').write(out + tab_o + tab_t + ids + strs)
print(n, 'entries')
