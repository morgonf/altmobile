#!/bin/sh
# Установка пересобранных модулей голосового тракта в дерево модулей.
# Заводские копии сохраняются рядом с суффиксом .orig, действующие убираются
# в .disabled. Откат скриптом q6revert.sh.
#
# После установки нужна перезагрузка: подмена на ходу не работает, udev
# успевает подгрузить заводской q6voice раньше нашего.

PATH=/sbin:/usr/sbin:$PATH
export PATH

D=/home/altlinux/q6build
DIR=/lib/modules/$(uname -r)/kernel/sound/soc/qcom/qdsp6
MODS="q6voice-common q6mvm q6cvs q6cvp q6voice"

run() {

echo "== до установки"
ls -l $DIR | grep -E 'q6(voice|mvm|cvs|cvp)'

for m in $MODS; do
	echo
	echo "-- $m"
	if [ ! -f $D/$m.ko ]; then
		echo "  НЕТ собранного $D/$m.ko, пропускаю"
		continue
	fi
	Z=$DIR/$m.ko.zst
	if [ -f "$Z" ]; then
		[ -f "$Z.orig" ] || { cp -a "$Z" "$Z.orig" && echo "  заводская копия сохранена в $m.ko.zst.orig"; }
		mv "$Z" "$Z.disabled" && echo "  заводской $m.ko.zst убран в .disabled"
	else
		echo "  заводского $m.ko.zst уже нет, копия должна быть в .orig"
		ls -l $DIR/$m.ko.zst.orig 2>&1 | sed 's/^/    /'
	fi
	install -m 644 $D/$m.ko $DIR/$m.ko && echo "  установлен наш $m.ko"
done

echo
echo "== depmod"
depmod -a && echo "  готово"

echo
echo "== после установки"
ls -l $DIR | grep -E 'q6(voice|mvm|cvs|cvp)'

echo
echo "Теперь нужна перезагрузка телефона."

}

run 2>&1 | tee /home/altlinux/q6install.log
chmod 644 /home/altlinux/q6install.log
