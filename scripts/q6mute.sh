#!/bin/sh
# Проверка, акустическое ли эхо. Ждёт ответа собеседника (ModemManager
# пишет «-> active»; голосовой тракт стартует раньше, ещё при наборе),
# через 15 секунд глушит микрофон на уровне кодека (ADC MUX7 в DMIC, у 6T
# цифровых микрофонов нет, в передачу идёт тишина) на 30 секунд и
# возвращает AMIC.
# Если собеседник в тишине продолжает слышать себя, петля цифровая.
# Запуск от root: systemd-run --unit=q6mute /home/altlinux/q6mute.sh

LOG=/home/altlinux/q6mute.log
exec >$LOG 2>&1
echo "$(date +%T) жду ответа собеседника"
journalctl -f -n0 -u ModemManager | grep -m1 -e "-> active" >/dev/null
echo "$(date +%T) собеседник ответил, через 15 с глушу микрофон"
sleep 15
amixer -c0 cset name='ADC MUX7' 0 >/dev/null
echo "$(date +%T) микрофон заглушён: $(amixer -c0 cget name='ADC MUX7' | tail -1)"
sleep 30
amixer -c0 cset name='ADC MUX7' 1 >/dev/null
echo "$(date +%T) микрофон возвращён: $(amixer -c0 cget name='ADC MUX7' | tail -1)"
chmod 644 $LOG
