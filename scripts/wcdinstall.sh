#!/bin/sh
# Установка драйвера кодека с ограниченной шкалой громкости разговорного динамика.
# Заводской модуль сохраняется рядом с суффиксом .orig, действующий убирается в
# .disabled, ничего не удаляется. Откат скриптом wcdrevert.sh плюс перезагрузка.

PATH=/sbin:/usr/sbin:$PATH
export PATH
D=/home/altlinux/wcdbuild
DIR=/lib/modules/$(uname -r)/kernel/sound/soc/codecs
M=snd-soc-wcd934x

echo "== было"
ls -l $DIR/$M* 2>&1

Z=$DIR/$M.ko.zst
if [ -f "$Z" ]; then
	if [ ! -f "$Z.orig" ]; then
		cp -a "$Z" "$Z.orig" && echo "  заводская копия сохранена в $M.ko.zst.orig"
	fi
	mv "$Z" "$Z.disabled" && echo "  заводской убран в .disabled"
else
	echo "  заводского $M.ko.zst нет, копия должна быть в .orig"
	ls -l $DIR/$M.ko.zst.orig 2>&1
fi

install -m 644 $D/$M.ko $DIR/$M.ko && echo "  установлен наш $M.ko"

depmod -a && echo "  depmod готов"

echo
echo "== стало"
ls -l $DIR/$M* 2>&1
echo
echo "Нужна перезагрузка телефона."
