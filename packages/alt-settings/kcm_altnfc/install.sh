#!/bin/sh
# Установка страницы «NFC» от root
B=/home/altlinux/alt-settings/kcm_altnfc
set -e
SO=$(find $B/build -name kcm_altnfc.so | head -1)
strip --strip-debug -o /tmp/kan.tmp "$SO"
install -m 644 /tmp/kan.tmp /usr/lib64/qt6/plugins/plasma/kcms/systemsettings/kcm_altnfc.so
rm -f /tmp/kan.tmp
ls -l /usr/lib64/qt6/plugins/plasma/kcms/systemsettings/kcm_altnfc.so
