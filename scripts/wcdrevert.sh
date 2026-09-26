#!/bin/sh
# Откат к заводскому драйверу кодека.

PATH=/sbin:/usr/sbin:$PATH
export PATH
DIR=/lib/modules/$(uname -r)/kernel/sound/soc/codecs
M=snd-soc-wcd934x

if [ -f $DIR/$M.ko.zst.orig ]; then
	cp -a $DIR/$M.ko.zst.orig $DIR/$M.ko.zst && echo "заводской вернут"
	rm -f $DIR/$M.ko.zst.disabled
else
	echo "заводской копии .orig нет, ничего не делаю"
fi
rm -f $DIR/$M.ko && echo "наш убран"
depmod -a && echo "depmod готов"
echo
ls -l $DIR/$M* 2>&1
echo
echo "Нужна перезагрузка телефона."
