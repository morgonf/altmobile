#!/bin/sh
# Включение отправки параметров калибровки. Отдельно от проверки отображения
# памяти. Перезагрузка телефона всё отменяет: файл прошивки остаётся, но
# параметр модуля сбрасывается.

set -e
install -D -m 644 /home/altlinux/q6voice-cal.bin /lib/firmware/q6voice-cal.bin
echo q6voice-cal.bin > /sys/module/q6voice/parameters/cal_firmware
echo "cal_firmware = $(cat /sys/module/q6voice/parameters/cal_firmware)"
echo "файл: $(ls -l /lib/firmware/q6voice-cal.bin)"
echo "Теперь позвонить и посмотреть dmesg."
