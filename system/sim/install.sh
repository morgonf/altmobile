#!/bin/sh
# Установка служб SIM, от root, из каталога со скриптом
cd "$(dirname "$0")"
install -m 755 alt-sim-hotplug.sh /usr/local/bin/
install -m 755 alt-sim-pin-notify.py /usr/local/bin/
install -m 644 alt-sim-hotplug.service /etc/systemd/system/
install -m 644 alt-sim-pin-notify.service /etc/systemd/user/
systemctl daemon-reload
systemctl enable --now alt-sim-hotplug.service
systemctl --global enable alt-sim-pin-notify.service
