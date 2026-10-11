#!/bin/sh
# Мобильный интернет и GPS при работающей SIM-карте (OnePlus 6T).
# Саму карту (гнездо, сессия USIM) с 11.10.2026 подхватывает alt-sim-slots.py
# по событиям модема, здесь раньше был опрос.
#
# Мобильный интернет. У подключения CON стоит autoconnect no: иначе
# NetworkManager на запертой карте уходит в need-auth и агент plasma-nm
# показывает своё окно «Вход в mts» поверх нашего окна PIN. Поднимаем
# подключение сами, один раз после того, как модем стал готов (после
# загрузки или разблокировки). Если пользователь потом выключит данные,
# не включаем их обратно, пока карта снова не окажется заперта.
CON=mts
UP=0
# Состояние кнопки «Местоположение» читается по маске geoclue, а запреты
# (polkit, гашение GPS ниже) по флагу. Если маска есть, а флага нет (так
# было на втором телефоне: маску перенесли с клоном из /etc, флаг в /var
# нет), Satellite читал координаты у модема при выключенной кнопке
if [ "$(systemctl is-enabled geoclue.service 2>/dev/null)" = masked ] &&
   [ ! -e /var/lib/alt-mobile/location-off ]; then
	mkdir -p -m 755 /var/lib/alt-mobile
	touch /var/lib/alt-mobile/location-off
	logger -t alt-sim-hotplug "geoclue запрещена, ставлю флаг location-off"
fi
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
	   mmcli -m any --location-status -K 2>/dev/null | grep -q "^modem.location.enabled .*gps"; then
		logger -t alt-sim-hotplug "местоположение выключено, гашу GPS модема"
		mmcli -m any --location-disable-gps-nmea --location-disable-gps-raw >/dev/null 2>&1
	fi
	sleep 3
done
