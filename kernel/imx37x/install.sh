#!/bin/sh
# Установка собранных imx371.ko и imx376.ko (build.sh). От root. Модули из
# updates/ перекрывают штатные. Откат: удалить их и выполнить depmod -a.
set -e
K=$(uname -r)
mkdir -p /lib/modules/$K/updates
for m in imx371 imx376; do
	install -m 644 "$(dirname "$0")"/$m.ko /lib/modules/$K/updates/$m.ko
done
/sbin/depmod -a
# Выгружать модули на ходу нельзя: после rmmod общие часы матриц не
# включаются снова (failed to enable inclk), а CAMSS не создаёт узлы
# подустройств заново. Новые модули заработают после перезагрузки.
echo "установлено, перезагрузите телефон"
