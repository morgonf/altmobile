#!/bin/sh
# Включает эхоподавитель ECNS v2 (модуль 0x10f1f) по-настоящему в каждом
# разговоре. Включение, пришедшее до начала передачи голоса, модуль
# откладывает и остаётся в обходе, а голосовой тракт стартует ещё при
# наборе номера. Процессор о начале разговора ничего не сообщает, поэтому
# слушаем сигнал ModemManager StateChanged по D-Bus: при переходе звонка в
# MM_CALL_STATE_ACTIVE (4), исходящего или входящего, выключаем и снова
# включаем модуль. Журнал для этого не годится, он запаздывает на секунды.

L=/sys/module/q6voice/parameters/live_set

dbus-monitor --system \
	"type='signal',interface='org.freedesktop.ModemManager1.Call',member='StateChanged'" |
while read -r line; do
	case "$line" in
	*member=StateChanged*)
		read -r old
		read -r new
		[ "$new" = "int32 4" ] || continue
		if echo "10f1f 10e00 0" > $L && echo "10f1f 10e00 1" > $L; then
			echo "разговор начался, эхоподавитель перезапущен"
		else
			echo "разговор начался, перезапустить эхоподавитель не удалось"
		fi
		;;
	esac
done
