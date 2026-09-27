#!/bin/sh
# Порядок загрузки ALT Mobile: цель alt-mobile.target и drop-in-файлы.
# От root, из каталога со скриптом. Остальные drop-in ставят свои install.sh
# (system/sensors: iio-sensor-proxy и plasma-mobile после датчиков).
cd "$(dirname "$0")"
install -m 644 alt-mobile.target /etc/systemd/system/
for u in ModemManager hexagonrpcd-sdsp hexagonrpcd-adsp-audio; do
	mkdir -p /etc/systemd/system/$u.service.d
	install -m 644 dropins/qcom-base.conf /etc/systemd/system/$u.service.d/qcom-base.conf
done
install -m 755 ../../scripts/alt-mobile-status /usr/local/bin/
mkdir -p /usr/share/doc/alt-mobile
install -m 644 ../../docs/boot-order.md /usr/share/doc/alt-mobile/
systemctl daemon-reload
systemctl enable alt-mobile.target
