#!/bin/sh
# Журнал батареи: battlog.sh СЕКУНДЫ ФАЙЛ [ШАГ]
# Каждые ШАГ секунд (по умолчанию 10) пишет время, счётчик заряда (мкА·ч),
# ток (мкА, минус при разряде) и напряжение bq27411.
B=/sys/class/power_supply/bq27411-0
end=$(( $(date +%s) + $1 )); step=${3:-10}
while [ "$(date +%s)" -lt "$end" ]; do
	printf "%s %s %s %s\n" "$(date +%s)" "$(cat $B/charge_now)" "$(cat $B/current_now)" "$(cat $B/voltage_now)" >> "$2"
	sleep "$step"
done
