#!/bin/sh
# Установка служб SIM, от root, из каталога со скриптом
cd "$(dirname "$0")"
install -m 755 alt-sim-hotplug.sh alt-sim-pin-notify.py alt-sim-unlock /usr/local/bin/
install -D -m 644 sim-unlock/main.qml /usr/share/alt-mobile/sim-unlock/main.qml
install -m 644 50-alt-mobile-sim.rules /etc/polkit-1/rules.d/
install -m 644 alt-sim-hotplug.service /etc/systemd/system/
install -m 644 alt-sim-pin-notify.service /etc/systemd/user/
# Подключение поднимает alt-sim-hotplug, когда модем готов (см. скрипт)
nmcli con modify mts connection.autoconnect no
# Следильщик модема в plasma-nm (kded networkmanagement) иначе выводит своё
# окно «Требуется разблокирование PIN-код SIM-карты», в том числе на
# sim-pin2, которое модем сообщает уже после разблокировки
su altlinux -c "kwriteconfig6 --file plasma-nm --group General --key UnlockModemOnDetection false"
systemctl daemon-reload
systemctl enable alt-sim-hotplug.service
systemctl restart alt-sim-hotplug.service
systemctl --global enable alt-sim-pin-notify.service
