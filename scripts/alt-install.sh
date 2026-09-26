#!/bin/bash
# Чистая переустановка ALT Mobile на раздел userdata телефона.
# ВНИМАНИЕ: раздел /dev/sda17 будет полностью стёрт.
set -e

D=/dev/sda17
T=/home/user/Загрузки/alt-mobile-phosh-sdm845-latest-aarch64.tar.xz
M=/mnt/alt_rootfs

die() { echo; echo "ОСТАНОВЛЕНО: $*"; exit 1; }

[ -b "$D" ] || die "нет устройства $D, телефон отключился"
[ -f "$T" ] || die "нет архива $T"

echo "=== что сейчас на разделе ==="
blkid "$D" || true

echo
echo "=== отмонтирую всё, что висит на $D ==="
for i in 1 2 3 4 5; do
	mp="$(findmnt -n -o TARGET --first-only "$D" 2>/dev/null || true)"
	[ -n "$mp" ] || break
	echo "  отмонтирую $mp"
	umount "$mp" || die "не удалось отмонтировать $mp"
done
findmnt -n "$D" >/dev/null 2>&1 && die "раздел всё ещё смонтирован"

echo
echo "=== создаю btrfs с меткой ROOT ==="
mkfs.btrfs -L ROOT -f "$D" || die "mkfs.btrfs не отработал"

sleep 3
# рабочий стол мог подхватить свежую ФС автоматически
for i in 1 2 3; do
	mp="$(findmnt -n -o TARGET --first-only "$D" 2>/dev/null || true)"
	[ -n "$mp" ] || break
	echo "  снова отмонтирую $mp"
	umount "$mp" || true
done

echo
echo "=== проверяю, что получилось именно btrfs с меткой ==="
blkid "$D"
[ "$(blkid -o value -s TYPE "$D")" = btrfs ]   || die "тип файловой системы не btrfs"
[ "$(blkid -o value -s LABEL "$D")" = ROOT ]   || die "метка не ROOT"
echo "проверка пройдена"

echo
echo "=== монтирую ==="
mkdir -p "$M"
mount "$D" "$M" || die "не смонтировалось"

echo
echo "=== распаковываю систему, это несколько минут ==="
tar xpf "$T" -C "$M" || die "распаковка не удалась"
echo "распаковано"

echo
echo "=== правлю тип корня в /etc/fstab с f2fs на btrfs ==="
sed -i 's|^\(LABEL=ROOT[[:space:]]\+/[[:space:]]\+\)f2fs|\1btrfs|' "$M/etc/fstab"
cat "$M/etc/fstab"

echo
echo "=== extlinux.conf, как есть в образе ==="
cat "$M/boot/extlinux/extlinux.conf"

echo
echo "=== содержимое /boot ==="
ls -l "$M/boot"

echo
echo "=== сбрасываю кэш на устройство ==="
sync
umount "$M" || die "не удалось отмонтировать, данные могли не долететь"
sync

echo
echo "=== ГОТОВО ==="
blkid "$D"
