#!/usr/bin/env python3
"""Разборщик файлов калибровки Qualcomm ACDB.

Формат проприетарный и неопубликованный, здесь собрано то, что удалось
установить достоверно на файлах с OnePlus 6T. Неразобранные места помечены.

Использование:
    acdb.py <файл> sections              список секций
    acdb.py <файл> lut <ИМЯ>             разбор таблицы вида *LUT
    acdb.py <файл> vpst                  статическая калибровка голоса, расшифровка
    acdb.py <файл> vpdy                  динамическая калибровка голоса
    acdb.py <файл> devprops [устр...]    свойства устройств и их топологии
    acdb.py <файл> hex <смещение> <длина>  шестнадцатеричный дамп
    acdb.py <файл> words <смещение> <сколько>  дамп как u32
    acdb.py <файл> find <0xЗНАЧЕНИЕ>     поиск u32 по всему файлу
"""

import struct
import sys

# Известные имена секций. Тройка LUT + CDFT + CDOT встречается для каждого
# вида калибровки: LUT это ключи, CDFT список параметров, CDOT смещения.
SECTION_NAMES = [
    b"MODIFIED", b"SWPNAME", b"SWPVERS", b"OEMINFO",
    b"GPROPLUT", b"DPROPLUT", b"DEVCATIN", b"DATAPOOL",
    b"GLBLLUT", b"MINFOLUT", b"ADSPVERS", b"CDCNAME",
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
    b"VPDYLUT0", b"VPDYCDFT", b"VPDYCDOT",
    b"VPSTLUT0", b"VPSTCDFT", b"VPSTCDOT",
]

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
    for off, name in sections(d):
        r = lut(d, name)
        extra = ""
        if r and name.endswith(("LUT", "LUT0")):
            extra = f"  длина {r[1]}, записей {r[2]}, запись {r[3]} байт"
        print(f"  {off:8}  {name}{extra}")


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
        "?поле5", "?поле6",
    ])


def cmd_vpdy(d, args):
    _decode_voice_lut(d, "VPDYLUT0", [
        "устройство_TX", "устройство_RX", "?поле3", "?поле4", "?поле5",
    ])


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
    "sections": cmd_sections, "lut": cmd_lut, "vpst": cmd_vpst,
    "vpdy": cmd_vpdy, "devprops": cmd_devprops, "hex": cmd_hex, "words": cmd_words, "find": cmd_find,
}


def main():
    if len(sys.argv) < 3 or sys.argv[2] not in COMMANDS:
        sys.exit(__doc__)
    d = load(sys.argv[1])
    COMMANDS[sys.argv[2]](d, sys.argv[3:])


if __name__ == "__main__":
    main()
