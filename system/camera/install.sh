#!/bin/sh
# Правило udev для вспышки (см. 71-alt-mobile-flash.rules), от root.
set -e
cd "$(dirname "$0")"
install -m 644 71-alt-mobile-flash.rules /etc/udev/rules.d/71-alt-mobile-flash.rules
udevadm control --reload
udevadm trigger --subsystem-match=leds --action=change
