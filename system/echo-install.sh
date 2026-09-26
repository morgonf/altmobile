#!/bin/sh
# Постоянная установка эхоподавления. Запуск от root, затем перезагрузка.
# Откат: echo-revert.sh.
set -e
PATH=/sbin:/usr/sbin:$PATH
H=/home/altlinux
UCM=/usr/share/alsa/ucm2/OnePlus/fajita/VoiceCall.conf

# модули голосового тракта
$H/q6install.sh >/dev/null
echo "модули установлены"

# калибровка и параметры модулей
install -m 644 $H/q6build/cal-v2-final.bin /lib/firmware/cal-v2-final.bin
install -m 644 $H/echo/q6voice-echo.conf /etc/modprobe.d/q6voice-echo.conf
echo "калибровка и /etc/modprobe.d/q6voice-echo.conf на месте"

# UCM: уровни микрофона в звонке
[ -f $UCM.pre-echo ] || cp -a $UCM $UCM.pre-echo
install -m 644 $H/echo/VoiceCall.conf $UCM
echo "UCM обновлён, прежний в $UCM.pre-echo"

# служба для ADSP
install -m 755 $H/hexrpc/hexagonrpcd-ftell /usr/local/sbin/hexagonrpcd-ftell
install -m 644 $H/echo/hexagonrpcd-adsp-audio.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable hexagonrpcd-adsp-audio.service
# Перезапуск подавителя после ответа на звонок. Ядро момент ответа не
# видит, его сообщает ModemManager. Порядок как в удачном ручном опыте:
# выключить модуль, через секунду включить, затем слово режима и усиление.
install -D -m 644 $H/echo/ecns-10e61.hex /usr/local/share/q6voice/ecns-10e61.hex
install -m 755 $H/echo/q6echo-activate.sh /usr/local/sbin/q6echo-activate.sh
install -m 644 $H/echo/q6echo-activate.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now q6echo-activate.service
echo "служба q6echo-activate включена"
echo "служба hexagonrpcd-adsp-audio включена"

# Без «пи-пи-пи» при завершении разговора: тема feedbackd, где событие
# phone-hangup заменено пустым. Ставится пользователю altlinux.
install -D -m 644 -o altlinux -g altlinux $H/echo/feedbackd-no-hangup.json \
	$H/.config/feedbackd/themes/no-hangup.json
echo "тема feedbackd no-hangup на месте, включить от пользователя:"
echo "  gsettings set org.sigxcpu.feedbackd theme no-hangup"
echo "Теперь перезагрузка."
