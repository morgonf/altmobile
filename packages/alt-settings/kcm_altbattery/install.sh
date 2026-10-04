#!/bin/sh
# Установка страницы «Батарея» от root. Службы ограничения заряда, оценку
# здоровья и правило polkit ставит system/battery/install.sh
B=/home/altlinux/alt-settings/kcm_altbattery
set -e
SO=$(find $B/build -name kcm_altbattery.so | head -1)
strip --strip-debug -o /tmp/kab.tmp "$SO"
install -m 644 /tmp/kab.tmp /usr/lib64/qt6/plugins/plasma/kcms/systemsettings/kcm_altbattery.so
rm -f /tmp/kab.tmp
ls -l /usr/lib64/qt6/plugins/plasma/kcms/systemsettings/kcm_altbattery.so
