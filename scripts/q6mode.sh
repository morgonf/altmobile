#!/bin/sh
# Записать в ECNS v2 главный параметр 0x10f1f/0x10e61 с другим словом режима
# (второе слово, заводское 0x0080032c). Остальные 164 байта заводские.
# Пример: q6mode.sh 0x0080032c   (заводское)
#         q6mode.sh 0x00800328   (без бита 2)
# Запуск от пользователя во время разговора.

M=$(printf %08x $(($1)))
LE=$(echo $M | sed 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/')
F=$(cat /home/altlinux/ecns-10e61-factory.hex)
HEX="${F:0:8}${LE}${F:16}"
echo "10f1f 10e61 hex:$HEX" > /sys/module/q6voice/parameters/live_set
echo "10f1f 10e61 168" > /sys/module/q6voice/parameters/live_get
journalctl -k -n 10 --no-pager | grep -E "live [sg]et|  0000:" | sed 's/.*kernel: //; s/q6voice-dai [^ ]* //'
