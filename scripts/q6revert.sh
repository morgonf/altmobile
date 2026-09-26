#!/bin/sh
# Откат к заводским модулям голосового тракта.

PATH=/sbin:/usr/sbin:$PATH
export PATH

DIR=/lib/modules/$(uname -r)/kernel/sound/soc/qcom/qdsp6
MODS="q6voice-common q6mvm q6cvs q6cvp q6voice"

run() {

for m in $MODS; do
	echo "-- $m"
	if [ -f $DIR/$m.ko.zst.orig ]; then
		cp -a $DIR/$m.ko.zst.orig $DIR/$m.ko.zst && echo "  заводской вернут"
		rm -f $DIR/$m.ko.zst.disabled
	else
		echo "  заводской копии .orig нет, ничего не делаю"
	fi
	rm -f $DIR/$m.ko && echo "  наш убран"
done

echo
depmod -a && echo "depmod готов"
echo
ls -l $DIR | grep -E 'q6(voice|mvm|cvs|cvp)'
echo
echo "Теперь нужна перезагрузка телефона."

}

run 2>&1 | tee /home/altlinux/q6revert.log
chmod 644 /home/altlinux/q6revert.log
