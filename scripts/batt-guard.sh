#!/bin/sh
# Приостанавливает службу сборки ($1) при нагреве батареи (на зарядке):
# выше 42 °C заморозка, ниже 38 °C продолжение. Пара к build-thermal-guard.sh,
# который следит за процессором.
U=$1
B=/sys/class/power_supply/bq27411-0/temp
while systemctl --user is-active -q "$U"; do
	t=$(cat $B)
	f=$(systemctl --user show -P FreezerState "$U")
	if [ "$t" -gt 420 ] && [ "$f" = running ]; then
		systemctl --user freeze "$U" && echo "$(date +%T) батарея $t заморожена"
	elif [ "$t" -lt 380 ] && [ "$f" = frozen ]; then
		systemctl --user thaw "$U" && echo "$(date +%T) батарея $t продолжена"
	fi
	sleep 10
done
