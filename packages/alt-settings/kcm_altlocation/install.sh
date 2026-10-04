#!/bin/sh
# Установка страницы «Местоположение» от root. Службы и правило polkit
# ставит system/plasma/quicksetting-location/install.sh
B=/home/altlinux/alt-settings/kcm_altlocation
set -e
SO=$(find $B/build -name kcm_altlocation.so | head -1)
strip --strip-debug -o /tmp/kal.tmp "$SO"
install -m 644 /tmp/kal.tmp /usr/lib64/qt6/plugins/plasma/kcms/systemsettings/kcm_altlocation.so
rm -f /tmp/kal.tmp
ls -l /usr/lib64/qt6/plugins/plasma/kcms/systemsettings/kcm_altlocation.so
