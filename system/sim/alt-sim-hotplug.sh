#!/bin/sh
# Подхват SIM-карты, вставленной при работающем телефоне (OnePlus 6T, QMI).
# Модем видит карту и приложение USIM, но не открывает основную сессию
# подготовки (Primary GW), и ModemManager остаётся в состоянии
# failed/sim-missing. Раз в 10 секунд: если ModemManager пишет sim-missing,
# а QMI видит карту с USIM без сессии, открываем сессию и перезапускаем
# ModemManager. Найдено и проверено вручную 27.09.2026.
DEV=qrtr://0
while true; do
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
