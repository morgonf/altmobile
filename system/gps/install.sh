#!/bin/sh
# GPS: NMEA при загрузке и агент geoclue. От root, из каталога со скриптом.
cd "$(dirname "$0")"
install -m 755 alt-gps-nmea.sh /usr/local/bin/
install -m 644 alt-gps-nmea.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now alt-gps-nmea.service
# Агент geoclue (разрешает программам доступ к местоположению); в KDE своего
# нет, демо-агент geoclue в белом списке и стартует из /etc/xdg/autostart.
apt-get install -y geoclue2-demo
