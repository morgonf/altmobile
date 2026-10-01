#!/bin/sh
# NFC на OnePlus 6T, от root: политика D-Bus для агентов neard, настройки
# neard (включение при загрузке), служба пользователя alt-nfc (опрос,
# блокировка экрана, уведомления, история), сброс зависшего чипа и плитка
# шторки. neard запускает udev (99-neard.rules) при появлении nfc0.
set -e
cd "$(dirname "$0")"
install -m 644 org.neard-alt-mobile.conf /etc/dbus-1/system.d/
install -d /etc/neard
install -m 644 main.conf /etc/neard/main.conf
install -m 755 alt-nfc-reset /usr/local/sbin/
install -m 644 alt-nfc-reset.service /etc/systemd/system/
install -m 644 50-alt-mobile-nfc.rules /etc/polkit-1/rules.d/
# Прежняя служба alt-nfc-poll вошла в alt-nfc
systemctl --global disable alt-nfc-poll.service 2>/dev/null || true
rm -f /usr/local/bin/alt-nfc-poll.py /etc/systemd/user/alt-nfc-poll.service
install -m 755 alt-nfc.py /usr/local/bin/
install -m 644 alt-nfc.service /etc/systemd/user/
systemctl --global enable alt-nfc.service
rm -rf /usr/share/plasma/quicksettings/ru.altlinux.quicksetting.nfc
cp -r ru.altlinux.quicksetting.nfc /usr/share/plasma/quicksettings/
chmod -R u=rwX,go=rX /usr/share/plasma/quicksettings/ru.altlinux.quicksetting.nfc
systemctl daemon-reload
busctl call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig
