#!/bin/sh
# Кнопка «Местоположение» в шторке Plasma Mobile, от root
set -e
cd "$(dirname "$0")"
Q=/usr/share/plasma/quicksettings/ru.altlinux.quicksetting.location
mkdir -p $Q
cp -r ru.altlinux.quicksetting.location/* $Q/
install -m 644 alt-location-off.service alt-location-on.service \
	alt-location-net-off.service alt-location-net-on.service /etc/systemd/system/
install -m 644 49-alt-mobile-location-off.rules 51-alt-mobile-location.rules /etc/polkit-1/rules.d/
systemctl daemon-reload
