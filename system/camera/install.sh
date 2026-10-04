#!/bin/sh
# Правило udev для вспышки (см. 71-alt-mobile-flash.rules) и настройка
# WirePlumber без монитора libcamera, от root. WirePlumber подхватит
# настройку при следующем входе или systemctl --user restart wireplumber.
set -e
cd "$(dirname "$0")"
install -m 644 71-alt-mobile-flash.rules /etc/udev/rules.d/71-alt-mobile-flash.rules
udevadm control --reload
udevadm trigger --subsystem-match=leds --action=change
install -D -m 644 50-alt-mobile-no-libcamera.conf /etc/wireplumber/wireplumber.conf.d/50-alt-mobile-no-libcamera.conf
