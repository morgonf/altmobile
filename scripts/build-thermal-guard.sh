#!/bin/sh
# Приостанавливает службу сборки ($1) при перегреве и продолжает после
# остывания: выше 85 °C заморозка, ниже 70 °C разморозка.
U=${1:-anim-build}
while systemctl --user is-active -q $U; do
	t=$(cat /sys/class/thermal/thermal_zone*/temp | sort -n | tail -1)
	f=$(systemctl --user show -P FreezerState $U)
	if [ $t -gt 85000 ] && [ "$f" = running ]; then
		systemctl --user freeze $U && echo "$(date +%T) $t заморожена"
	elif [ $t -lt 70000 ] && [ "$f" = frozen ]; then
		systemctl --user thaw $U && echo "$(date +%T) $t продолжена"
	fi
	sleep 5
done
