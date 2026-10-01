#!/bin/sh
# Установка «Темы и обоев» от root
B=/home/altlinux/alt-settings/kcm_altappearance
set -e
SO=$(find $B/build -name kcm_altappearance.so | head -1)
strip --strip-debug -o /tmp/kaa.tmp "$SO"
install -m 644 /tmp/kaa.tmp /usr/lib64/qt6/plugins/plasma/kcms/systemsettings/kcm_altappearance.so
rm -f /tmp/kaa.tmp
install -d /usr/libexec/alt-mobile
install -m 755 $B/set-color-scheme /usr/libexec/alt-mobile/set-color-scheme
ls -l /usr/lib64/qt6/plugins/plasma/kcms/systemsettings/kcm_altappearance.so /usr/libexec/alt-mobile/set-color-scheme
