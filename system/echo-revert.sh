#!/bin/sh
# Откат постоянного эхоподавления. Запуск от root, затем перезагрузка.
PATH=/sbin:/usr/sbin:$PATH
UCM=/usr/share/alsa/ucm2/OnePlus/fajita/VoiceCall.conf
systemctl disable --now hexagonrpcd-adsp-audio.service q6echo-activate.service
rm -f /etc/systemd/system/q6echo-activate.service /usr/local/sbin/q6echo-activate.sh
rm -f /etc/systemd/system/hexagonrpcd-adsp-audio.service /etc/modprobe.d/q6voice-echo.conf
systemctl daemon-reload
[ -f $UCM.pre-echo ] && mv $UCM.pre-echo $UCM
echo "Служба, параметры модулей и UCM откачены. Модули голосового тракта: q6revert.sh"
