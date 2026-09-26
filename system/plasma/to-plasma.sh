#!/bin/sh
# Переключить графический сеанс на Plasma Mobile. Phosh остаётся установлен.
# Обратно: to-phosh.sh. Действует после перезапуска сеанса или перезагрузки.
set -e
# plasma-mobile не тянет за собой эти пакеты, а без них сеанс падает:
# без plasma6-integration KWin падает с SIGSEGV в QKdeTheme::createKdeTheme,
# без plasma6-breeze и qqc2-breeze-style нет оформления и стиля QML.
apt-get install -y plasma-mobile plasma6-integration plasma6-breeze \
	qqc2-breeze-style icon-theme-breeze plasma-keyboard maliit-keyboard
install -m 644 /home/altlinux/echo/plasma/plasma-mobile.service /etc/systemd/system/
install -m 755 /home/altlinux/echo/plasma/plasma-mobile-session /usr/local/bin/plasma-mobile-session
systemctl daemon-reload
systemctl disable phosh.service
systemctl enable plasma-mobile.service
readlink -f /etc/systemd/system/display-manager.service
