#!/bin/sh
# Проверка, проходит ли эхо через микрофон, без остановки потока передачи.
# Глушение через ADC MUX7 останавливало весь поток SLIMBUS_0_TX (микрофон
# потом не возвращался), поэтому ничего не доказывало. Здесь опускается
# только цифровое усиление DEC7 на 54 дБ: поток идёт, но микрофон почти
# беззвучен. Через 15 с после ответа на 20 с, затем прежнее значение.
# Запуск от root: systemd-run --unit=q6dec7 --collect /home/altlinux/q6dec7.sh

LOG=/home/altlinux/q6dec7.log
exec >$LOG 2>&1
echo "$(date +%T) жду ответа собеседника"
journalctl -f -n0 -u ModemManager | grep -m1 -e "-> active" >/dev/null
echo "$(date +%T) собеседник ответил"
sleep 15
OLD=$(amixer -c0 cget name='DEC7 Volume' | sed -n 's/.*: values=//p')
amixer -c0 cset name='DEC7 Volume' 30 >/dev/null
echo "$(date +%T) DEC7 $OLD -> $(amixer -c0 cget name='DEC7 Volume' | sed -n 's/.*: values=//p')"
sleep 20
amixer -c0 cset name='DEC7 Volume' $OLD >/dev/null
echo "$(date +%T) DEC7 возвращён: $(amixer -c0 cget name='DEC7 Volume' | sed -n 's/.*: values=//p')"
chmod 644 $LOG
