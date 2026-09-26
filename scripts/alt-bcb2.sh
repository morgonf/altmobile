#!/bin/bash
# Читает и выставляет блок управления загрузчиком (BCB) в разделе misc.
# Ищет раздел по имени, буква устройства меняется после каждой перезагрузки телефона.
set -e

D=$(readlink -f /dev/disk/by-partlabel/misc 2>/dev/null || true)

[ -n "$D" ] && [ -b "$D" ] || {
	echo "раздел misc не найден. Телефон подключён и в спасательном режиме?"
	echo "что вижу:"
	ls -l /dev/disk/by-partlabel/ 2>&1 | head
	exit 1
}

echo "misc найден: $D"
sz=$(blockdev --getsize64 "$D")
echo "размер: $sz байт"
[ "$sz" -le 8388608 ] || { echo "ОСТАНОВЛЕНО: слишком большой, это не misc"; exit 1; }

echo
echo "=== поле command, как есть сейчас ==="
dd if="$D" bs=1 count=32 status=none | od -A d -c

echo
echo "=== поле status ==="
dd if="$D" bs=1 skip=32 count=32 status=none | od -A d -c

echo
echo "=== пишу bootonce-bootloader ==="
python3 -c "import sys; sys.stdout.buffer.write(b'bootonce-bootloader'.ljust(32, b'\x00'))" \
	| dd of="$D" bs=1 count=32 conv=notrunc status=none
sync
blockdev --flushbufs "$D" 2>/dev/null || true

echo "=== перечитываю с устройства ==="
dd if="$D" bs=1 count=32 status=none | od -A d -c

echo
echo "ЗАПИСАНО. Выключите телефон удержанием питания, затем включите."
