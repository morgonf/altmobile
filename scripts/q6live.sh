#!/bin/sh
# Приводит идущий разговор в рабочее состояние эхоподавления. Ждёт ответа
# собеседника, затем:
#  - выключает и снова включает модуль ECNS v2 (0x10f1f): включение при
#    создании сессии модуль откладывает и фактически остаётся в обходе;
#  - усиление последнего модуля цепочки 0x10ef4/0x10e12 в 0xC000: работающий
#    подавитель сильно приглушает голос;
#  - заводские усиления микрофона ADC4 12, DEC7 84: с ними меньше шума.
# Требует q6v2.sh (внешняя опора, открытые live_set и live_get).
# Запуск от root: systemd-run --unit=q6live --collect /home/altlinux/q6live.sh

L=/sys/module/q6voice/parameters
LOG=/home/altlinux/q6live.log
exec >$LOG 2>&1
echo "$(date +%T) жду ответа собеседника"
journalctl -f -n0 -u ModemManager | grep -m1 -e "-> active" >/dev/null
sleep 1
echo "10f1f 10e00 0" > $L/live_set
sleep 1
echo "10f1f 10e00 1" > $L/live_set
echo "10ef4 10e12 0xC000" > $L/live_set
amixer -c0 cset name='ADC4 Volume' 12 >/dev/null
amixer -c0 cset name='DEC7 Volume' 84 >/dev/null
echo "$(date +%T) подавитель переключён, усиление 0xC000, ADC4 12, DEC7 84"
# PipeWire может вернуть ADC4 на 20, держим до конца звонка
while ! journalctl -u ModemManager --since "-3s" | grep -q -e "-> terminated"; do
	[ "$(amixer -c0 cget name='ADC4 Volume' | sed -n 's/.*: values=//p')" = 12 ] ||
		{ amixer -c0 cset name='ADC4 Volume' 12 >/dev/null; echo "$(date +%T) ADC4 снова 12"; }
	sleep 1
done
echo "$(date +%T) звонок окончен"
chmod 644 $LOG
