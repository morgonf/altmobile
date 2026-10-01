#!/bin/sh
# NFC на OnePlus 6T, от root: политика D-Bus для агентов neard и настройки
# neard (включение при загрузке, постоянный опрос). neard запускает udev
# (99-neard.rules) при появлении nfc0, здесь только перезапуск.
set -e
cd "$(dirname "$0")"
install -m 644 org.neard-alt-mobile.conf /etc/dbus-1/system.d/
install -d /etc/neard
install -m 644 main.conf /etc/neard/main.conf
install -m 755 alt-nfc-poll.py /usr/local/bin/
install -m 755 alt-nfc-reset /usr/local/sbin/
install -m 644 alt-nfc-reset.service /etc/systemd/system/
install -m 644 50-alt-mobile-nfc.rules /etc/polkit-1/rules.d/
systemctl daemon-reload
install -m 644 alt-nfc-poll.service /etc/systemd/user/
systemctl --global enable alt-nfc-poll.service
busctl call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig
systemctl restart neard
sleep 2
nfctool --list
