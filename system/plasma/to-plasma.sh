#!/bin/sh
# Переключить графический сеанс на Plasma Mobile. Phosh остаётся установлен.
# Обратно: to-phosh.sh. Действует после перезапуска сеанса или перезагрузки.
set -e
# plasma-mobile не тянет за собой эти пакеты. Без plasma6-integration KWin
# падает с SIGSEGV в QKdeTheme::createKdeTheme. Без powerdevil кнопку питания
# обрабатывает logind и выключает телефон. Без остальных нет оформления,
# сети, громкости, экрана и Bluetooth в интерфейсе.
apt-get install -y plasma-mobile plasma6-integration plasma6-breeze \
	qqc2-breeze-style icon-theme-breeze plasma-keyboard maliit-keyboard \
	powerdevil plasma-nm plasma-pa kscreen bluedevil xdg-desktop-portal-kde \
	plasma-settings qmlkonsole kalk calindori krecorder koko spectacle \
	plasma-nm-connect-mobile
# plasma-settings 26.08.1 собирается отдельно, см. packages/README.md
# Русский перевод модуля навигации (в KDE строки этого модуля не выгружаются)
install -m 644 /home/altlinux/echo/plasma/kcm_navigation.mo /usr/share/locale/ru/LC_MESSAGES/kcm_navigation.mo
install -m 644 /home/altlinux/echo/private-tmp.conf /etc/tmpfiles.d/private-tmp.conf
# Обход падения plasmashell в Qt 6.11.2 при открытии настроек виджета
F=/usr/share/plasma/shells/org.kde.plasma.mobileshell/contents/configuration/AppletConfiguration.qml
[ -f $F.orig ] || cp -a $F $F.orig
install -m 644 /home/altlinux/echo/plasma/AppletConfiguration.qml $F
# Мастер первого запуска Plasma Mobile не нужен: телефон уже настроен, а его
# шаг мобильной связи без конца перезапускал подключение mts (2575 раз за
# несколько минут), и окно запроса секрета мигало, не давая ничего ввести.
su altlinux -c "kwriteconfig6 --file plasmamobilerc --group General --key wizardRun true"
# без сна при простое, как было под Phosh
install -D -m 644 -o altlinux -g altlinux /home/altlinux/echo/plasma/powerdevilrc \
	/home/altlinux/.config/powerdevilrc
install -m 644 /home/altlinux/echo/plasma/plasma-mobile.service /etc/systemd/system/
install -m 755 /home/altlinux/echo/plasma/plasma-mobile-session /usr/local/bin/plasma-mobile-session
systemctl daemon-reload
systemctl disable phosh.service
systemctl enable plasma-mobile.service
readlink -f /etc/systemd/system/display-manager.service
