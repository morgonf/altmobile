#!/bin/sh
# ALT Mobile: ограничение заряда батареи. Литий-ионная батарея быстрее
# стареет, пока держится у 100 % (у 6T это 4,4 В), а телефон подолгу лежит
# на зарядке. Драйвер зарядки qcom_smbx умеет только отключать вход USB
# (запись в status: "Unknown" ставит USBIN_SUSPEND, любое другое значение
# снимает), поэтому заряд держится между RESUME и LIMIT: на LIMIT вход
# отключается и телефон живёт от батареи, на RESUME включается снова.
# Пока вход отключён, драйвер показывает зарядку отключённой (online 0).
# Настройки в /etc/alt-mobile/charge-limit (LIMIT, RESUME).
CHG=/sys/class/power_supply/pmi8998-charger/status
BAT=/sys/class/power_supply/bq27411-0/capacity
LIMIT=80
RESUME=75
[ -r /etc/alt-mobile/charge-limit ] && . /etc/alt-mobile/charge-limit

resume() { echo Charging > $CHG; }
suspend() { echo Unknown > $CHG; }

# Что бы ни случилось со службой, зарядка не должна остаться выключенной
trap 'resume; exit 0' TERM INT EXIT
state=
while :; do
	cap=$(cat $BAT 2>/dev/null)
	case "$cap" in
	''|*[!0-9]*) want=on ;;
	*)	if [ "$cap" -ge "$LIMIT" ]; then want=off
		elif [ "$cap" -le "$RESUME" ]; then want=on
		else want=${state:-on}
		fi ;;
	esac
	if [ "$want" != "$state" ]; then
		if [ $want = off ]; then suspend; else resume; fi
		echo "заряд ${cap:-?} %, вход USB $( [ $want = off ] && echo отключён || echo включён)"
		state=$want
	fi
	sleep 60 &
	wait $!
done
