#!/bin/sh
# Во время звонка каждые 250 мс читает слово режима ECNS v2 (0x10f1f/0x10e61)
# в журнал ядра, 40 секунд с начала набора. Нужно понять, поднимает ли
# процессор бит 0 сам в момент начала разговора.
# Запуск от root: systemd-run --unit=q6poll --collect /home/altlinux/q6poll.sh
journalctl -k -f -n0 | grep -m1 "start path" >/dev/null
exec >/home/altlinux/q6poll.log 2>&1
i=0
while [ $i -lt 160 ]; do
	echo "10f1f 10e61 168" > /sys/module/q6voice/parameters/live_get 2>/dev/null
	sleep 0.25
	i=$((i+1))
done
