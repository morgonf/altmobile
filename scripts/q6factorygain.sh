#!/bin/sh
# Проверка на один звонок: заводские усиления микрофона из mixer_paths_tavil.xml
# (ADC4 Volume 12, DEC7 Volume 84) вместо наших 20 и 81. При наших тон из
# разговорного динамика приходил в микрофонный тракт громче исходного, на
# 4 дБ, то есть громкая речь собеседника обрезалась в тракте передачи и
# подавитель вычитать её уже не мог. PipeWire держит ADC4 как громкость
# микрофона и выставляет 20, поэтому значения поддерживаются весь звонок.
# Запуск от root: systemd-run --unit=q6gain --collect /home/altlinux/q6factorygain.sh

LOG=/home/altlinux/q6factorygain.log
exec >$LOG 2>&1
echo "$(date +%T) жду ответа собеседника"
journalctl -f -n0 -u ModemManager | grep -m1 -e "-> active" >/dev/null
echo "$(date +%T) собеседник ответил"
echo "  было: ADC4 $(amixer -c0 cget name='ADC4 Volume' | sed -n 's/.*: values=//p'), DEC7 $(amixer -c0 cget name='DEC7 Volume' | sed -n 's/.*: values=//p')"
n=0
while journalctl -u ModemManager --since "-3s" | grep -q -e "-> terminated"; [ $? -ne 0 ]; do
	a=$(amixer -c0 cget name='ADC4 Volume' | sed -n 's/.*: values=//p')
	d=$(amixer -c0 cget name='DEC7 Volume' | sed -n 's/.*: values=//p')
	if [ "$a" != 12 ] || [ "$d" != 84 ]; then
		amixer -c0 cset name='ADC4 Volume' 12 >/dev/null
		amixer -c0 cset name='DEC7 Volume' 84 >/dev/null
		echo "$(date +%T) выставлено ADC4 12, DEC7 84 (было $a, $d)"
	fi
	n=$((n+1)); [ $n -gt 600 ] && break
	sleep 1
done
echo "$(date +%T) звонок окончен"
chmod 644 $LOG
