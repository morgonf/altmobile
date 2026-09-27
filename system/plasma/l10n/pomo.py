#!/usr/bin/env python3
"""Минимальный компилятор .po в .mo с поддержкой msgctxt (без множественных форм)."""
import ast, struct, sys

def parse(path):
    entries, cur, key = [], {}, None
    for line in open(path, encoding='utf-8'):
        line = line.strip()
        if not line or line.startswith('#'):
            if cur.get('msgid') is not None: entries.append(cur); cur = {}
            continue
        if line.startswith('"'):
            cur[key] += ast.literal_eval(line); continue
        k, v = line.split(' ', 1)
        if k == 'msgctxt' and cur.get('msgid') is not None: entries.append(cur); cur = {}
        key = k; cur[k] = ast.literal_eval(v)
    if cur.get('msgid') is not None: entries.append(cur)
    return entries

def compile_mo(entries, out):
    msgs = {}
    for e in entries:
        k = e['msgid'] if 'msgctxt' not in e else e['msgctxt'] + '\x04' + e['msgid']
        msgs[k.encode()] = e['msgstr'].encode()
    keys = sorted(msgs)
    ids = b''.join(k + b'\0' for k in keys); strs = b''.join(msgs[k] + b'\0' for k in keys)
    n = len(keys); o1 = 7 * 4; o2 = o1 + n * 8; base = o2 + n * 8
    ko, vo, p = [], [], 0
    for k in keys: ko += [len(k), base + p]; p += len(k) + 1
    base2 = base + len(ids); p = 0
    for k in keys: vo += [len(msgs[k]), base2 + p]; p += len(msgs[k]) + 1
    data = struct.pack('<7I', 0x950412de, 0, n, o1, o2, 0, 0) + struct.pack(f'<{2*n}I', *ko) + struct.pack(f'<{2*n}I', *vo) + ids + strs
    open(out, 'wb').write(data)

compile_mo(parse(sys.argv[1]), sys.argv[2]); print('ok', sys.argv[2])
