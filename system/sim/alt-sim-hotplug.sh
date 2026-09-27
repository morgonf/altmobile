#!/bin/sh
# Подхват SIM-карты, вставленной при работающем телефоне (OnePlus 6T, QMI).
# Модем видит карту и приложение USIM, но не открывает основную сессию
# подготовки (Primary GW), и ModemManager остаётся в состоянии
# failed/sim-missing. Раз в 10 секунд: если ModemManager пишет sim-missing,
# а QMI видит карту с USIM без сессии, открываем сессию и перезапускаем
# ModemManager. Найдено и проверено вручную 27.09.2026.
#
# Мобильный интернет. У подключения CON стоит autoconnect no: иначе
# NetworkManager на запертой карте уходит в need-auth и агент plasma-nm
# показывает своё окно «Вход в mts» поверх нашего окна PIN. Поднимаем
# подключение сами, один раз после того, как модем стал готов (после
# загрузки или разблокировки). Если пользователь потом выключит данные,
# не включаем их обратно, пока карта снова не окажется заперта.
DEV=qrtr://0
CON=mts
UP=0
while true; do
	ST=$(mmcli -m any -K 2>/dev/null | sed -n 's/^modem.generic.state *: //p')
	case "$ST" in
	locked|"") UP=0 ;;
	registered|connected)
		if [ $UP = 0 ]; then
			UP=1
			if [ "$(nmcli -t radio wwan)" = enabled ] &&
			   ! nmcli -t -f TYPE con show --active | grep -q gsm; then
				logger -t alt-sim-hotplug "модем готов ($ST), поднимаю $CON"
				nmcli con up "$CON" 2>&1 | logger -t alt-sim-hotplug
			fi
		fi ;;
	esac
	# Местоположение выключено кнопкой в шторке: приёмник GPS держим
	# выключенным, даже если программа включила его через ModemManager
	if [ -e /var/lib/alt-mobile/location-off ] &&
	   mmcli -m any --location-status 2>/dev/null | grep -q "enabled:.*gps"; then
		logger -t alt-sim-hotplug "местоположение выключено, гашу GPS модема"
		mmcli -m any --location-disable-gps-nmea --location-disable-gps-raw >/dev/null 2>&1
	fi
	if mmcli -m any 2>/dev/null | grep -q "failed reason: sim-missing"; then
		ST=$(qmicli -p -d $DEV --uim-get-card-status 2>/dev/null)
		if echo "$ST" | grep -q "Primary GW:   session doesn't exist" &&
		   echo "$ST" | grep -q "Card state: 'present'"; then
			# AID первого приложения USIM в слоте 1
			AID=$(echo "$ST" | awk '/Slot \[1\]/{s=1} s&&/usim/{u=1} u&&/Application ID:/{getline; gsub(/[ \t]/,""); print; exit}')
			if [ -n "$AID" ]; then
				logger -t alt-sim-hotplug "SIM вставлена, открываю сессию USIM $AID"
				qmicli -p -d $DEV --uim-change-provisioning-session="session-type=primary-gw-provisioning,activate=yes,slot=1,aid=$AID" | logger -t alt-sim-hotplug
				sleep 3
				systemctl restart ModemManager
				sleep 20
			fi
		fi
	fi
	sleep 10
done
