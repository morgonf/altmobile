#!/bin/sh
# Ограничение заряда и оценка здоровья батареи, от root. Ограничение
# ставится выключенным, его включает страница «Батарея» или
# systemctl enable --now alt-charge-limit
set -e
cd "$(dirname "$0")"
install -D -m 755 alt-charge-limit.sh /usr/lib/alt-mobile/alt-charge-limit.sh
install -m 755 alt-battery-health.sh /usr/lib/alt-mobile/alt-battery-health.sh
install -m 644 alt-charge-limit.service alt-charge-limit-on.service \
	alt-charge-limit-off.service alt-battery-health.service \
	alt-battery-health.timer /etc/systemd/system/
install -m 644 51-alt-mobile-battery.rules /etc/polkit-1/rules.d/
[ -e /etc/alt-mobile/charge-limit ] || install -D -m 644 charge-limit /etc/alt-mobile/charge-limit
systemctl daemon-reload
systemctl enable --now alt-battery-health.timer
systemctl start alt-battery-health.service
