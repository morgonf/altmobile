#!/bin/sh
# ALT Mobile: оценка здоровья батареи от датчика bq27421 для страницы
# «Батарея». Драйвер ядра bq27xxx её не показывает, поэтому команда
# StateOfHealth (0x20) читается напрямую, только чтение. Младший байт
# это проценты, старший состояние оценки (3 значит готова).
# Пишет /run/alt-mobile/battery-health: SOH=<проценты> SOH_STATUS=<0..3>
v=$(/usr/sbin/i2cget -f -y 10 0x55 0x20 w) || exit 1
mkdir -p /run/alt-mobile
printf 'SOH=%d\nSOH_STATUS=%d\n' $((v & 0xff)) $((v >> 8)) > /run/alt-mobile/battery-health.tmp
mv /run/alt-mobile/battery-health.tmp /run/alt-mobile/battery-health
