#!/bin/sh
# Поиск лицензионных данных для процессора на разделах устройства.
# Разделы монтируются только для чтения, ничего не меняется.

PATH=/sbin:/usr/sbin:$PATH
export PATH
LOG=/home/altlinux/q6lic.log
M=/mnt/q6lic

run() {
mkdir -p $M
for part in dsp_a persist vendor_a; do
	DEV=/dev/disk/by-partlabel/$part
	echo "=============== $part ==============="
	[ -e "$DEV" ] || { echo "нет устройства"; continue; }
	echo "тип: $(blkid -o value -s TYPE $DEV 2>/dev/null), размер: $(blockdev --getsize64 $DEV 2>/dev/null)"

	umount $M 2>/dev/null
	if mount -o ro $DEV $M 2>&1; then
		echo "-- смонтирован, верхний уровень:"
		ls $M | head -20 | tr '\n' ' '; echo
		echo "-- файлы с lic в имени:"
		find $M -iname '*lic*' 2>/dev/null | head -30
		echo "-- файлы с внутренней строкой license:"
		grep -rlis license $M 2>/dev/null | head -20
		echo "-- всё в каталогах с acdb или firmware:"
		find $M -ipath '*acdb*' -o -ipath '*firmware*' 2>/dev/null | head -40
		umount $M
	else
		echo "-- не монтируется, ищу строку в сырых байтах"
		for pat in license LICENSE adsp_license; do
			n=$(strings -a -n 6 $DEV 2>/dev/null | grep -c -- "$pat")
			echo "   строка '$pat': $n совпадений"
		done
	fi
	echo
done
rmdir $M 2>/dev/null
}

run 2>&1 | tee $LOG
chmod 644 $LOG
