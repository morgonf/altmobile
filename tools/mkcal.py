#!/usr/bin/env python3
"""Сборка самодельного набора параметров для драйвера q6voice.

Формат тот же, что выдаёт `acdb.py export`, магия `Q6VCAL01`. Нужен, когда
параметр надо задать руками, а не взять из заводской калибровки: например
включить модуль обработки, которого в калибровке нет вовсе.

Использование:
    mkcal.py <файл> модуль:параметр:значение [ещё...]

Значение задаётся одним из трёх видов:
    число            одно слово u32, как есть
    ч,ч,ч            несколько слов u32 через запятую
    hex:ааббввгг     байты в шестнадцатеричном виде

Пример, включить подавитель первой версии:
    mkcal.py cal.bin 0x10ee0:0x10e00:1
"""

import struct
import sys

MAGIC = b"Q6VCAL01"
VERSION = 1


def parse_value(text):
    if text.startswith("hex:"):
        return bytes.fromhex(text[4:])
    words = [int(x, 0) for x in text.split(",")]
    return b"".join(struct.pack("<I", w) for w in words)


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    path = sys.argv[1]
    body = b""
    count = 0
    total = 0
    for spec in sys.argv[2:]:
        parts = spec.split(":")
        if len(parts) != 3:
            sys.exit(f"не разобрать {spec!r}, нужно модуль:параметр:значение")
        mod, par, val = int(parts[0], 0), int(parts[1], 0), parse_value(parts[2])
        body += struct.pack("<III", mod, par, len(val)) + val
        body += b"\0" * (-len(val) % 4)
        count += 1
        total += len(val)
        print(f"  модуль 0x{mod:08x} параметр 0x{par:08x} "
              f"{len(val)} байт: {val.hex(' ')}")

    head = MAGIC + struct.pack("<IIIIIII", VERSION, 0, 0, 0, 0, count, total)
    with open(path, "wb") as f:
        f.write(head + body)
    print(f"{path}: {count} параметров, {total} байт данных, "
          f"файл {len(head) + len(body)} байт")


if __name__ == "__main__":
    main()
