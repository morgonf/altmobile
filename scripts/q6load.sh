#!/bin/sh
# Загрузка пересобранных модулей голосового тракта.
# В систему ничего не устанавливается, модули берутся из /home/altlinux/q6build,
# поэтому перезагрузка телефона возвращает заводское состояние.
#
# Вывод дублируется в /home/altlinux/q6load.log.

D=/home/altlinux/q6build
DRV=/sys/bus/platform/drivers/q6voice-dai
DEV=remoteproc-adsp:glink-edge:apr:apr-service@9:dais

run() {

echo "== было"
lsmod | grep -E '^q6(voice|cvp|mvm|cvs)'

echo
echo "== отвязываю звуковые dai, иначе q6voice_dai занят"
if [ -e "$DRV/$DEV" ]; then
	echo "$DEV" > "$DRV/unbind" 2>&1 && echo "  отвязано" || echo "  НЕ отвязалось"
else
	echo "  устройство и так не привязано"
fi
sleep 1
echo "  refcnt q6voice_dai: $(cat /sys/module/q6voice_dai/refcnt 2>/dev/null)"

echo
echo "== выгружаю старые"
for m in q6voice_dai q6voice q6cvp q6mvm q6cvs q6voice_common; do
	[ -d /sys/module/$m ] || continue
	if rmmod $m 2>&1; then
		echo "  выгружен $m"
	else
		echo "  НЕ ВЫГРУЗИЛСЯ $m, refcnt=$(cat /sys/module/$m/refcnt 2>/dev/null), holders=$(ls /sys/module/$m/holders 2>/dev/null | tr '\n' ' ')"
	fi
done

echo
echo "== загружаю новые"
for m in q6voice-common q6mvm q6cvs q6cvp q6voice; do
	if insmod $D/$m.ko 2>&1; then
		echo "  загружен $m"
	else
		echo "  ОШИБКА на $m"
	fi
done

echo
echo "== возвращаю заводской q6voice_dai"
modprobe q6voice_dai 2>&1 && echo "  загружен"
sleep 2
if [ -e "$DRV/$DEV" ]; then
	echo "  устройство привязано"
else
	echo "  привязываю вручную"
	echo "$DEV" > "$DRV/bind" 2>&1 || echo "  не привязалось"
fi

echo
echo "== параметры нового q6voice"
ls /sys/module/q6voice/parameters/ 2>&1
if [ -e /sys/module/q6voice/parameters/mem_map_test ]; then
	echo 1 > /sys/module/q6voice/parameters/mem_map_test
	echo "  mem_map_test = $(cat /sys/module/q6voice/parameters/mem_map_test)"
else
	echo "  ПАРАМЕТРА НЕТ, значит загружен заводской модуль"
fi

echo
echo "== стало"
lsmod | grep -E '^q6(voice|cvp|mvm|cvs)'

echo
echo "== звуковая карта"
aplay -l 2>&1 | head -6

echo
echo "Готово. Теперь позвонить."

}

run 2>&1 | tee /home/altlinux/q6load.log
chmod 644 /home/altlinux/q6load.log
