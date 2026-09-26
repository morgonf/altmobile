#!/usr/bin/env python3
"""Разборщик файлов калибровки Qualcomm ACDB.

Формат проприетарный и неопубликованный, здесь собрано то, что удалось
установить достоверно на файлах с OnePlus 6T. Неразобранные места помечены.

Использование:
    acdb.py <файл> sections              список секций, с проверкой на разрывы
    acdb.py <файл> lut <ИМЯ>             разбор таблицы вида *LUT
    acdb.py <файл> sets <ИМЯ>            разбор секции из наборов (CDFT, CDOT, OFST, CVD0)
    acdb.py <файл> vpst                  статическая калибровка голоса, расшифровка
    acdb.py <файл> vpdy                  динамическая калибровка голоса
    acdb.py <файл> cal <TX> <RX> [--dyn] [--list] [--entry N]   цепочка калибровки
    acdb.py <файл> export <TX> <RX> <вариант> <файл> [--dyn] [--modules список]  выгрузка
    acdb.py <файл> devprops [устр...]    свойства устройств и их топологии
    acdb.py <файл> hex <смещение> <длина>  шестнадцатеричный дамп
    acdb.py <файл> words <смещение> <сколько>  дамп как u32
    acdb.py <файл> find <0xЗНАЧЕНИЕ>     поиск u32 по всему файлу
"""

import struct
import sys

# Известные имена секций. Для каждого вида калибровки есть LUT (ключи),
# CDFT (список параметров), CDOT (смещения данных). У голосовых видов
# добавляются OFST (пары ссылок на наборы CDFT и CDOT) и CVD0 (ключи CVD).
SECTION_NAMES = [
    b"MODIFIED", b"SWPNAME", b"SWPVERS", b"OEMINFO",
    b"GPROPLUT", b"DPROPLUT", b"CPROPLUT", b"DEVCATIN", b"DATAPOOL",
    b"GLBLLUT", b"MINFOLUT", b"ADSPVERS", b"CDCNAME", b"ACSWVER2",
    b"AFE LUT0", b"AFE CDFT", b"AFE CDOT", b"ANC LUT0",
    b"WMCALUT0", b"WMCACDFT", b"WMCACDOT",
    b"WMCNLUT0", b"WMCNCDFT", b"WMCNCDOT",
    b"WSGCLUT0", b"WSGCCDFT", b"WSGCCDOT",
    b"WDMILUT0", b"WDMICDFT", b"WDMICDOT",
    b"WMIDLUT0", b"WMIDCDFT", b"WMIDCDOT",
    b"WDPRPLUT", b"WGPRPLUT",
    b"ASTMLUT0", b"ASTMCDFT", b"ASTMCDOT",
    b"VST2LUT0", b"VST2CDFT", b"VST2CDOT",
    b"ACGILUT0", b"ACGICDFT", b"ACGICDOT",
    b"ACGDLUT0", b"ACGDCDFT", b"ACGDCDOT",
    b"AVOLLUT0", b"AVOLCDFT", b"AVOLCDOT",
    b"AFECLUT0", b"AFECCDFT", b"AFECCDOT",
    b"VDPILUT0", b"VDPICDFT", b"VDPICDOT",
    b"LSMCLUT0", b"LSMCCDFT", b"LSMCCDOT",
    b"CDFSLUT0", b"ADSTLUT0", b"ADSTCDFT", b"ADSTCDOT",
    b"AANCLUT0", b"AANCCDFT", b"AANCCDOT",
    b"VVP3LUT0", b"VVP3CDFT", b"VVP3CDOT",
    b"AVP3LUT0", b"AVP3CDFT", b"AVP3CDOT",
    b"EVP3LUT0", b"EVP3CDFT", b"EVP3CDOT",
    b"VPDYLUT0", b"VPDYCDFT", b"VPDYCDOT", b"VPDYCVD0", b"VPDYOFST",
    b"VPSTLUT0", b"VPSTCDFT", b"VPSTCDOT", b"VPSTCVD0", b"VPSTOFST",
]

# Размер элемента внутри набора, по виду секции. CDFT это пары
# (идентификатор модуля, идентификатор параметра), CDOT одиночные смещения
# в DATAPOOL, OFST пары (смещение набора CDFT, смещение набора CDOT),
# CVD0 ключ запроса со стороны CVD: 7 слов у статической таблицы,
# 8 у динамической (лишнее слово это ступень громкости).
SET_ELEM_SIZE = {"CDFT": 8, "CDOT": 4, "OFST": 8, "CVD0": 28}

SAMPLE_RATES = {8000: "8 кГц", 16000: "16 кГц", 32000: "32 кГц",
                44100: "44,1 кГц", 48000: "48 кГц", 96000: "96 кГц",
                192000: "192 кГц"}

# Свойства устройств из DPROPLUT. Значения лежат в DATAPOOL как
# u32 размер, затем данные. Расшифровано не всё.
DEVICE_PROPS = {
    0x000113af: "идентификатор топологии",
    0x000113b3: "идентификатор устройства AFE",
    0x000113b6: "?113b6",
    0x000113b7: "?113b7",
    0x000113b8: "имя устройства (UTF-16)",
    0x000113ad: "?113ad",
    0x000113a9: "?113a9",
    0x00013150: "?13150",
    0x00012a4b: "?12a4b",
    0x00012ecd: "?12ecd",
    0x00012eed: "?12eed",
    0x0001323e: "?1323e",
}

VOICE_TOPOLOGIES = {
    0x00010F70: "TOPOLOGY_ID_NONE",
    0x00010F71: "TX_SM_ECNS (v1)",
    0x00010F72: "TX_DM_FLUENCE",
    0x00010F77: "RX_DEFAULT",
    0x00010F86: "?f86, встречается в калибровке",
    0x00010F87: "?f87, встречается в калибровке",
    0x00010F88: "?f88, встречается в калибровке",
    0x00010F89: "TX_SM_ECNS_V2",
    0x00010F8B: "?f8b, встречается в калибровке",
}


def load(path):
    with open(path, "rb") as f:
        d = f.read()
    if d[:8] != b"QCMSNDDB":
        sys.exit(f"{path}: не файл ACDB, магия {d[:8]!r}")
    return d


def chunk_name(d):
    return d[16:20].decode(errors="replace").strip("\0")


def sections(d):
    """Найденные секции: [(смещение, имя)] в порядке по файлу."""
    found = []
    for name in SECTION_NAMES:
        off = d.find(name)
        while off != -1:
            found.append((off, name.decode()))
            off = d.find(name, off + 1)
    return sorted(set(found))


def lut(d, name):
    """Таблица вида *LUT: u32 длина, u32 число записей, затем записи.

    Возвращает (смещение, длина, число, размер_записи, [записи как кортежи u32]).
    Для секций CDFT и CDOT такой разбор НЕ работает, их структура иная.
    """
    if isinstance(name, str):
        name = name.encode()
    off = d.find(name)
    if off == -1:
        return None
    length, count = struct.unpack_from("<II", d, off + 8)
    body = length - 4
    esz = body // count if count else 0
    base = off + 16
    rows = []
    if esz and esz % 4 == 0:
        nw = esz // 4
        for i in range(count):
            rows.append(struct.unpack_from("<" + "I" * nw, d, base + i * esz))
    return off, length, count, esz, rows


def elem_size(name):
    """Размер элемента набора для секции CDFT, CDOT, OFST или CVD0."""
    if isinstance(name, bytes):
        name = name.decode()
    esz = SET_ELEM_SIZE.get(name[4:])
    if esz == 28 and name.startswith("VPDY"):
        return 32                       # у динамической таблицы лишнее слово
    return esz


def sets(d, name):
    """Секция из наборов: подряд идут блоки «u32 число, затем элементы».

    Секция целиком это `имя(8) u32 длина` и далее ровно `длина` байт
    содержимого, поэтому `u32` сразу за длиной это число элементов первого
    набора, а не число записей секции. Ссылаются на наборы по смещению
    внутри содержимого, то есть по смещению их собственного поля «число».

    Возвращает {смещение_набора: [кортежи u32]} или None, если секции нет.
    Бросает ValueError, если разбор не сошёлся с границей секции.
    """
    if isinstance(name, str):
        name = name.encode()
    off = d.find(name)
    if off == -1:
        return None
    esz = elem_size(name)
    if not esz:
        raise ValueError(f"{name.decode()}: неизвестный размер элемента")
    length, = struct.unpack_from("<I", d, off + 8)
    base, end = off + 12, off + 12 + length
    nw = esz // 4
    out, p = {}, base
    while p < end:
        rel = p - base
        count, = struct.unpack_from("<I", d, p)
        p += 4
        if p + count * esz > end:
            raise ValueError(f"{name.decode()}: набор на {rel} "
                             f"из {count} элементов не влезает в секцию")
        out[rel] = [struct.unpack_from("<" + "I" * nw, d, p + i * esz)
                    for i in range(count)]
        p += count * esz
    if p != end:
        raise ValueError(f"{name.decode()}: разбор кончился на {p}, ждали {end}")
    return out


def datapool(d):
    off = d.find(b"DATAPOOL")
    if off == -1:
        return None
    length, = struct.unpack_from("<I", d, off + 8)
    return off + 12, length


def cmd_sections(d, args):
    print(f"магия: {d[:8].decode()}   чанк: {chunk_name(d)}   размер: {len(d)}")
    dp = datapool(d)
    if dp:
        print(f"DATAPOOL: данные с {dp[0]}, длина {dp[1]}")
    print()
    found = sections(d)
    prev_end = None
    for off, name in found:
        length, = struct.unpack_from("<I", d, off + 8)
        gap = "" if prev_end is None or prev_end == off else \
            f"   <<< РАЗРЫВ {off - prev_end} байт, секция не опознана"
        r = lut(d, name)
        extra = ""
        if r and name.endswith(("LUT", "LUT0")):
            extra = f"  длина {r[1]}, записей {r[2]}, запись {r[3]} байт"
        elif elem_size(name):
            try:
                s = sets(d, name)
                extra = f"  длина {length}, наборов {len(s)}, " \
                        f"элементов {sum(len(v) for v in s.values())}"
            except ValueError as e:
                extra = f"  длина {length}, РАЗБОР НЕ СОШЁЛСЯ: {e}"
        else:
            extra = f"  длина {length}"
        print(f"  {off:8}  {name}{extra}{gap}")
        prev_end = off + 12 + length


def cmd_lut(d, args):
    r = lut(d, args[0])
    if not r:
        sys.exit(f"секция {args[0]} не найдена")
    off, length, count, esz, rows = r
    print(f"{args[0]}: смещение {off}, длина {length}, записей {count}, запись {esz} байт")
    if esz % 4:
        print("ВНИМАНИЕ: размер записи не кратен 4, разбор как u32 недостоверен")
    for i, row in enumerate(rows[:40]):
        print(f"  [{i:3}] " + " ".join(f"0x{w:08x}" for w in row))
    if len(rows) > 40:
        print(f"  ... ещё {len(rows) - 40}")


def _decode_voice_lut(d, name, fields):
    r = lut(d, name)
    if not r:
        sys.exit(f"секция {name} не найдена")
    off, length, count, esz, rows = r
    print(f"{name}: записей {count}, запись {esz} байт, поля: {', '.join(fields)}")
    print()
    for i, row in enumerate(rows):
        parts = []
        for fname, val in zip(fields, row):
            if "частота" in fname:
                parts.append(f"{fname}={SAMPLE_RATES.get(val, val)}")
            elif fname.startswith("?"):
                parts.append(f"{fname}=0x{val:08x}")
            else:
                parts.append(f"{fname}={val}")
        print(f"  [{i:3}] " + "  ".join(parts))


def cmd_vpst(d, args):
    _decode_voice_lut(d, "VPSTLUT0", [
        "устройство_TX", "устройство_RX", "частота_TX", "частота_RX",
        "OFST", "CVD0",
    ])


def cmd_vpdy(d, args):
    _decode_voice_lut(d, "VPDYLUT0", [
        "устройство_TX", "устройство_RX", "?поле3", "OFST", "CVD0",
    ])


def cmd_sets(d, args):
    if not args:
        sys.exit("нужно имя секции, например VPSTCDFT")
    s = sets(d, args[0])
    if s is None:
        sys.exit(f"секция {args[0]} не найдена")
    print(f"{args[0]}: наборов {len(s)}, элементов {sum(len(v) for v in s.values())}")
    for rel, items in s.items():
        print(f"  набор на {rel:6}: {len(items)} элементов")
        for it in items[:6]:
            print("      " + " ".join(f"0x{w:08x}" for w in it))
        if len(items) > 6:
            print(f"      ... ещё {len(items) - 6}")


def _cal_param_rows(d, cdft_set, cdot_set):
    """Пары «параметр, его данные» для одного набора."""
    dp, dplen = datapool(d)
    rows = []
    for (mod, par), (off,) in zip(cdft_set, cdot_set):
        size, = struct.unpack_from("<I", d, dp + off)
        first, = struct.unpack_from("<I", d, dp + off + 4) if size >= 4 else (None,)
        rows.append((mod, par, off, size, first, off + 4 + size <= dplen))
    return rows


def cmd_cal(d, args):
    """Цепочка LUT -> OFST -> (CDFT, CDOT) -> DATAPOOL для пары устройств."""
    dyn = "--dyn" in args
    entry = None
    if "--entry" in args:
        entry = int(args[args.index("--entry") + 1])
    nums = [int(a) for a in args if not a.startswith("--") and a.isdigit()]
    if entry is not None:
        nums = nums[:-1] if nums and nums[-1] == entry else nums
    if len(nums) < 2:
        sys.exit("нужны номера устройств TX и RX, например: cal 4 7")
    tx, rx = nums[0], nums[1]

    pre = "VPDY" if dyn else "VPST"
    r = lut(d, pre + "LUT0")
    if not r:
        sys.exit(f"{pre}LUT0 не найден")
    ofst, cvd = sets(d, pre + "OFST"), sets(d, pre + "CVD0")
    cdft, cdot = sets(d, pre + "CDFT"), sets(d, pre + "CDOT")
    rows = [w for w in r[4] if w[0] == tx and w[1] == rx]
    if not rows:
        sys.exit(f"в {pre}LUT0 нет пары устройств {tx}/{rx}")

    print(f"{pre}LUT0: пара {tx}/{rx}, строк {len(rows)}")
    for row in rows:
        keys = row[2:-2]
        kd = "  ".join(SAMPLE_RATES.get(k, str(k)) for k in keys)
        ofs, cvo = row[-2], row[-1]
        pairs, cvds = ofst[ofs], cvd[cvo]
        total = 0
        for (a, b) in pairs:
            total += sum(x[3] for x in _cal_param_rows(d, cdft[a], cdot[b]))
        print(f"\n  ключи: {kd}   OFST={ofs} CVD0={cvo}   "
              f"записей {len(cvds)}, данных {total} байт")
        if "--list" in args:
            for i, (k, (a, b)) in enumerate(zip(cvds, pairs)):
                np = len(cdft[a])
                sz = sum(x[3] for x in _cal_param_rows(d, cdft[a], cdot[b]))
                print(f"    [{i:3}] " + " ".join(f"0x{w:08x}" for w in k)
                      + f"   параметров {np:3}, {sz:5} байт")
        if entry is None:
            continue
        if entry >= len(cvds):
            sys.exit(f"записей всего {len(cvds)}")
        a, b = pairs[entry]
        print(f"  запись {entry}: ключ CVD "
              + " ".join(f"0x{w:08x}" for w in cvds[entry])
              + f"   CDFT={a} CDOT={b}")
        for mod, par, off, size, first, ok in _cal_param_rows(d, cdft[a], cdot[b]):
            note = "" if ok else "  ЗА ГРАНИЦЕЙ DATAPOOL"
            en = ""
            if par == 0x00010E00 and size == 4:          # включение модуля
                en = "  включён" if first else "  ВЫКЛЮЧЕН"
            print(f"      модуль 0x{mod:08x}  параметр 0x{par:08x}  "
                  f"смещение {off:6}  размер {size:5}{en}{note}")


def cmd_export(d, args):
    """Выгрузка калибровки варианта в файл для драйвера.

    Формат файла свой, не заводской. Заводская раскладка на проводе решается
    драйвером, здесь только перенос данных без потерь.

        магия "Q6VCAL01"   8 байт
        u32 версия = 1
        u32 устройство_TX   u32 устройство_RX
        u32 частота_TX      u32 частота_RX
        u32 число_параметров
        u32 размер_данных_всех_параметров без выравнивания
        далее по числу параметров:
            u32 модуль   u32 параметр   u32 размер   данные, добитые до 4 байт
    """
    dyn = "--dyn" in args
    only = None
    if "--modules" in args:
        only = {int(x, 0) for x in args[args.index("--modules") + 1].split(",")}
        args = [a for i, a in enumerate(args)
                if i not in (args.index("--modules"), args.index("--modules") + 1)]
    nums = [int(a) for a in args if a.isdigit()]
    out = [a for a in args if not a.startswith("--") and not a.isdigit()]
    if len(nums) < 3 or not out:
        sys.exit("нужно: export <TX> <RX> <вариант> <файл> [--dyn] [--modules 0x..,0x..]")
    tx, rx, entry = nums[0], nums[1], nums[2]
    path = out[0]

    pre = "VPDY" if dyn else "VPST"
    r = lut(d, pre + "LUT0")
    ofst, cvd = sets(d, pre + "OFST"), sets(d, pre + "CVD0")
    cdft, cdot = sets(d, pre + "CDFT"), sets(d, pre + "CDOT")
    rows = [w for w in r[4] if w[0] == tx and w[1] == rx]
    if not rows:
        sys.exit(f"в {pre}LUT0 нет пары устройств {tx}/{rx}")
    row = rows[0]
    pairs = ofst[row[-2]]
    if entry >= len(pairs):
        sys.exit(f"вариантов всего {len(pairs)}")
    a, b = pairs[entry]
    params = _cal_param_rows(d, cdft[a], cdot[b])
    if only is not None:
        params = [p for p in params if p[0] in only]
        if not params:
            sys.exit("ни один параметр варианта не принадлежит указанным модулям")
    bad = [p for p in params if not p[5]]
    if bad:
        sys.exit("данные параметра выходят за границу DATAPOOL, выгрузка отменена")

    dp, _ = datapool(d)
    body = b""
    for mod, par, off, size, _first, _ok in params:
        blob = d[dp + off + 4: dp + off + 4 + size]
        body += struct.pack("<III", mod, par, size) + blob
        body += b"\0" * (-size % 4)
    rate_tx, rate_rx = (row[2], row[3]) if pre == "VPST" else (0, 0)
    head = b"Q6VCAL01" + struct.pack("<IIIIIII", 1, tx, rx, rate_tx, rate_rx,
                                     len(params), sum(p[3] for p in params))
    with open(path, "wb") as f:
        f.write(head + body)
    print(f"{path}: {len(params)} параметров, {sum(p[3] for p in params)} байт "
          f"данных, файл {len(head) + len(body)} байт")
    print(f"ключ CVD варианта: "
          + " ".join(f"0x{w:08x}" for w in cvd[row[-1]][entry]))


def cmd_hex(d, args):
    off, ln = int(args[0], 0), int(args[1], 0)
    blob = d[off:off + ln]
    for i in range(0, len(blob), 16):
        chunk = blob[i:i + 16]
        txt = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)
        print(f"  {off + i:8}  {chunk.hex(' '):<48}  {txt}")


def cmd_words(d, args):
    off, n = int(args[0], 0), int(args[1], 0)
    for i in range(n):
        w, = struct.unpack_from("<I", d, off + i * 4)
        note = VOICE_TOPOLOGIES.get(w, "")
        print(f"  {off + i * 4:8}  0x{w:08x}  {w:>12}  {note}")


def cmd_find(d, args):
    val = int(args[0], 0)
    pat = struct.pack("<I", val)
    hits = []
    start = 0
    while True:
        i = d.find(pat, start)
        if i == -1:
            break
        hits.append(i)
        start = i + 1
    print(f"0x{val:08x}: найдено {len(hits)} раз")
    for i in hits[:40]:
        print(f"  смещение {i}{'  (выровнено)' if i % 4 == 0 else ''}")


def cmd_devprops(d, args):
    """Свойства устройств: DPROPLUT плюс значения из DATAPOOL."""
    o = d.find(b"DPROPLUT")
    if o == -1:
        sys.exit("DPROPLUT не найден, это не файл устройства")
    length, count = struct.unpack_from("<II", d, o + 8)
    base = o + 16
    rows = [struct.unpack_from("<III", d, base + i * 12) for i in range(count)]
    dp = d.find(b"DATAPOOL") + 12          # данные идут сразу после длины
    only = {int(a) for a in args} if args else None
    devs = sorted({r[0] for r in rows})
    for dev in devs:
        if only and dev not in only:
            continue
        print(f"--- устройство {dev}")
        for dv, prop, off in rows:
            if dv != dev:
                continue
            size, = struct.unpack_from("<I", d, dp + off)
            val, = struct.unpack_from("<I", d, dp + off + 4)
            name = DEVICE_PROPS.get(prop, f"0x{prop:08x}")
            note = ""
            if prop == 0x000113b8:                      # имя в UTF-16
                raw = d[dp + off + 4: dp + off + 4 + size]
                note = repr(raw.decode("utf-16-le", errors="ignore").rstrip("\0"))
            elif val in VOICE_TOPOLOGIES:
                note = f"<<< {VOICE_TOPOLOGIES[val]}"
            print(f"    {name:28} размер {size:3}  значение 0x{val:08x}  {note}")


COMMANDS = {
    "sections": cmd_sections, "lut": cmd_lut, "sets": cmd_sets,
    "vpst": cmd_vpst, "vpdy": cmd_vpdy, "cal": cmd_cal, "export": cmd_export,
    "devprops": cmd_devprops, "hex": cmd_hex, "words": cmd_words,
    "find": cmd_find,
}


def main():
    if len(sys.argv) < 3 or sys.argv[2] not in COMMANDS:
        sys.exit(__doc__)
    d = load(sys.argv[1])
    COMMANDS[sys.argv[2]](d, sys.argv[3:])


if __name__ == "__main__":
    main()
