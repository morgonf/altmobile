#!/bin/sh
# Датчики OnePlus 6T через SSC. От root, из каталога со скриптом.
# Нужны пакеты hexagonrpcd, libssc (Sisyphus) и iio-sensor-proxy, собранный
# с --enable ssc_support (packages/iio-sensor-proxy).
cd "$(dirname "$0")"
systemctl enable --now hexagonrpcd-sdsp.service
install -m 644 81-alt-mobile-sensors.rules /etc/udev/rules.d/
mkdir -p /etc/systemd/system/iio-sensor-proxy.service.d
install -m 644 iio-sensor-proxy-ssc.conf /etc/systemd/system/iio-sensor-proxy.service.d/ssc.conf
systemctl daemon-reload
udevadm control --reload
udevadm trigger --subsystem-match=misc
systemctl restart iio-sensor-proxy.service
