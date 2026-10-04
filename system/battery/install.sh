#!/bin/sh
# Ограничение заряда батареи, от root. Служба ставится выключенной,
# включение: systemctl enable --now alt-charge-limit
set -e
cd "$(dirname "$0")"
install -D -m 755 alt-charge-limit.sh /usr/lib/alt-mobile/alt-charge-limit.sh
install -m 644 alt-charge-limit.service /etc/systemd/system/
[ -e /etc/alt-mobile/charge-limit ] || install -D -m 644 charge-limit /etc/alt-mobile/charge-limit
systemctl daemon-reload
