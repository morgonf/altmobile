#!/bin/sh
# Загрузка пересобранных модулей голосового тракта.
# Ничего в системе не устанавливается: модули берутся из /home/altlinux/q6build,
# поэтому перезагрузка телефона возвращает всё к заводскому состоянию.

D=/home/altlinux/q6build
set -e

echo "== было загружено"
lsmod | grep -E '^q6(voice|cvp|mvm|cvs)' || true

echo
echo "== выгружаю старые"
for m in q6voice_dai q6cvp q6mvm q6cvs q6voice q6voice_common; do
	if lsmod | grep -q "^$m "; then
		rmmod $m && echo "  выгружен $m" || echo "  НЕ ВЫГРУЗИЛСЯ $m"
	fi
done

echo
echo "== загружаю новые"
for m in q6voice-common q6mvm q6cvs q6cvp q6voice; do
	insmod $D/$m.ko && echo "  загружен $m" || { echo "  ОШИБКА на $m"; exit 1; }
done

echo
echo "== возвращаю заводской q6voice_dai"
modprobe q6voice_dai && echo "  загружен q6voice_dai" || echo "  НЕ ЗАГРУЗИЛСЯ q6voice_dai"

echo
echo "== включаю проверку отображения памяти"
echo 1 > /sys/module/q6voice/parameters/mem_map_test
cat /sys/module/q6voice/parameters/mem_map_test

echo
echo "== стало загружено"
lsmod | grep -E '^q6(voice|cvp|mvm|cvs)' || true

echo
echo "== звуковая карта"
aplay -l 2>&1 | head -5 || true

echo
echo "Готово. Теперь позвонить и посмотреть dmesg."
