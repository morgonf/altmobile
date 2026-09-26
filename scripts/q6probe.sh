#!/bin/sh
# Включение перебора топологий и действующей калибровки после перезагрузки.
# Параметры модулей при перезагрузке сбрасываются, этот скрипт их возвращает.
# Запуск от root, затем позвонить и смотреть journalctl -k -b | grep probe:

set -e
printf %s cal-ec-coef.bin > /sys/module/q6voice/parameters/cal_firmware
echo Y > /sys/module/q6voice/parameters/probe_topologies
for f in /sys/module/q6voice/parameters/cal_firmware \
	 /sys/module/q6voice/parameters/probe_topologies \
	 /sys/module/q6cvp/parameters/*; do
	echo "$(basename $f) = $(cat $f)"
done
