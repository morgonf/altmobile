#!/bin/sh
# Приостанавливает службу сборки ($1) при нагреве батареи (на зарядке):
# выше 42 °C заморозка, ниже 38 °C продолжение. Без зарядки ниже 20 %
# тоже заморозка, до зарядки (сборка с камерой сажала батарею до 21 %).
# Пара к build-thermal-guard.sh, который следит за процессором.
U=$1
B=/sys/class/power_supply/bq27411-0
while systemctl --user is-active -q "$U"; do
	t=$(cat $B/temp)
	c=$(cat $B/capacity)
	low=0
	[ "$c" -lt 20 ] && [ "$(cat $B/status)" = Discharging ] && low=1
	f=$(systemctl --user show -P FreezerState "$U")
	if { [ "$t" -gt 420 ] || [ $low = 1 ]; } && [ "$f" = running ]; then
		systemctl --user freeze "$U" && echo "$(date +%T) батарея $t, заряд $c %, заморожена"
	elif [ "$t" -lt 380 ] && [ $low = 0 ] && [ "$f" = frozen ]; then
		systemctl --user thaw "$U" && echo "$(date +%T) батарея $t, заряд $c %, продолжена"
	fi
	sleep 10
done
