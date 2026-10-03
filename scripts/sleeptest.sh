#!/bin/sh
# Расход во сне (s2idle): sleeptest.sh СЕКУНДЫ ФАЙЛ, от root.
# Спит до конца срока; если что-то будит раньше, пишет причину и засыпает снова.
export PATH=/sbin:/usr/sbin:$PATH
B=/sys/class/power_supply/bq27411-0
end=$(( $(date +%s) + $1 )); L=$2
echo "start $(date +%s) $(cat $B/charge_now) $(cat $B/voltage_now)" > "$L"
while :; do
	left=$(( end - $(date +%s) ))
	[ "$left" -lt 20 ] && break
	rtcwake -m freeze -s "$left" >/dev/null 2>&1
	echo "wake $(date +%s) $(cat $B/charge_now) irq=$(cat /sys/power/pm_wakeup_irq 2>/dev/null) $(grep -h . /sys/power/suspend_stats/last_failed_dev 2>/dev/null)" >> "$L"
	sleep 2
done
echo "end $(date +%s) $(cat $B/charge_now) $(cat $B/voltage_now)" >> "$L"
grep -H . /sys/power/suspend_stats/* >> "$L" 2>/dev/null
chmod 644 "$L"
