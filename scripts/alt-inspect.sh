#!/bin/bash
# Осмотр раздела телефона. Только чтение, ничего не меняет.

D=/dev/sda17
M=/mnt/alt_inspect

echo "=== blkid ==="
blkid "$D"

echo
echo "=== монтирую только на чтение ==="
mkdir -p "$M"
mount -o ro "$D" "$M" || { echo "ОШИБКА монтирования"; exit 1; }
echo "смонтировано"

echo
echo "=== занято место ==="
df -h "$M" | tail -1

echo
echo "=== корень раздела ==="
ls -1 "$M"

echo
echo "=== /etc/fstab ==="
cat "$M/etc/fstab" 2>&1

echo
echo "=== /boot ==="
ls -l "$M/boot" 2>&1 | head -20

echo
echo "=== /boot/extlinux/extlinux.conf ==="
cat "$M/boot/extlinux/extlinux.conf" 2>&1

echo
echo "=== следы Android (если раздел не был переформатирован) ==="
for d in app data misc system user user_de media vendor_de unencrypted; do
	[ -e "$M/$d" ] && echo "найдено: /$d"
done

echo
echo "=== журналы загрузки ==="
ls -1 "$M/var/log/journal" 2>&1 | head
ls -l "$M/var/log/" 2>&1 | head -15

echo
echo "=== отмонтирую ==="
umount "$M" && echo "готово"
