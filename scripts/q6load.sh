#!/bin/sh
# Загрузка пересобранных модулей голосового тракта.
# В систему ничего не устанавливается, модули берутся из /home/altlinux/q6build,
# поэтому перезагрузка телефона возвращает заводское состояние.
#
# Вывод дублируется в /home/altlinux/q6load.log.

# У su -c каталога /sbin в PATH нет, а rmmod, insmod и modprobe лежат именно там
PATH=/sbin:/usr/sbin:$PATH
export PATH

D=/home/altlinux/q6build
DRV=/sys/bus/platform/drivers/q6voice-dai
DEV=remoteproc-adsp:glink-edge:apr:apr-service@9:dais

unbind_dai() {
	[ -e "$DRV/$DEV" ] || return 0
	echo "$DEV" > "$DRV/unbind" 2>&1 && echo "  dai отвязаны" || echo "  dai НЕ отвязались"
	sleep 1
}

bind_dai() {
	[ -e "$DRV/$DEV" ] && { echo "  dai уже привязаны"; return 0; }
	echo "$DEV" > "$DRV/bind" 2>&1 && echo "  dai привязаны" || echo "  dai НЕ привязались"
}

drop_all() {
	unbind_dai
	for m in q6voice_dai q6voice q6cvp q6mvm q6cvs q6voice_common; do
		[ -d /sys/module/$m ] || continue
		rmmod $m 2>&1 && echo "  выгружен $m" \
			|| echo "  НЕ ВЫГРУЗИЛСЯ $m, refcnt=$(cat /sys/module/$m/refcnt 2>/dev/null)"
	done
}

# Наш q6voice отличается от заводского наличием параметра mem_map_test
ours_loaded() {
	[ -e /sys/module/q6voice/parameters/mem_map_test ]
}

run() {

echo "== было"
lsmod | grep -E '^q6(voice|cvp|mvm|cvs)'

echo
echo "== выгружаю всё заводское"
drop_all

echo
echo "== загружаю общий слой и службы"
for m in q6voice-common q6cvs q6cvp q6mvm; do
	insmod $D/$m.ko 2>&1 && echo "  загружен $m" || echo "  ОШИБКА на $m"
done

# Вставка q6mvm создаёт устройство dai, и udev успевает сам подгрузить
# заводские q6voice_dai и q6voice. Их надо убрать, иначе наш q6voice не встанет.
sleep 2
if [ -d /sys/module/q6voice ] && ! ours_loaded; then
	echo
	echo "== udev подгрузил заводской q6voice, убираю его"
	unbind_dai
	for m in q6voice_dai q6voice; do
		[ -d /sys/module/$m ] || continue
		rmmod $m 2>&1 && echo "  выгружен $m" \
			|| echo "  НЕ ВЫГРУЗИЛСЯ $m, refcnt=$(cat /sys/module/$m/refcnt 2>/dev/null)"
	done
fi

echo
echo "== загружаю наш q6voice"
insmod $D/q6voice.ko 2>&1 && echo "  загружен q6voice" || echo "  ОШИБКА на q6voice"

echo
echo "== возвращаю заводской q6voice_dai"
if [ -d /sys/module/q6voice_dai ]; then
	echo "  уже загружен"
else
	modprobe q6voice_dai 2>&1 && echo "  загружен" || echo "  НЕ загрузился"
fi
sleep 2
bind_dai

echo
echo "== параметры q6voice"
ls /sys/module/q6voice/parameters/ 2>&1
if ours_loaded; then
	echo 1 > /sys/module/q6voice/parameters/mem_map_test
	echo "  mem_map_test = $(cat /sys/module/q6voice/parameters/mem_map_test)"
	echo "  НАШИ МОДУЛИ НА МЕСТЕ"
else
	echo "  ПАРАМЕТРА НЕТ, загружен заводской модуль"
fi

echo
echo "== стало"
lsmod | grep -E '^q6(voice|cvp|mvm|cvs)'

echo
echo "== топологии в микшере"
amixer -c 0 cget name='VoiceMMode1 TX Topology' 2>&1 | tail -1
amixer -c 0 cget name='VoiceMMode1 RX Topology' 2>&1 | tail -1

echo
echo "== звуковая карта"
aplay -l 2>&1 | head -4

echo
echo "Готово."

}

run 2>&1 | tee /home/altlinux/q6load.log
chmod 644 /home/altlinux/q6load.log
