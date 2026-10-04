#!/bin/sh
# Установка страницы «Хранилище» от root: модуль, помощник KAuth
# org.altmobile.storage (служба D-Bus, политика и действия polkit)
B=/home/altlinux/alt-settings/kcm_altstorage
set -e
cd $B/build
SO=$(find . -name kcm_altstorage.so | head -1)
strip --strip-debug -o /tmp/kst.tmp "$SO"
install -m 644 /tmp/kst.tmp /usr/lib64/qt6/plugins/plasma/kcms/systemsettings/kcm_altstorage.so
rm -f /tmp/kst.tmp
# Помощник и его файлы ставит cmake, кроме модуля (он уже на месте)
cmake --install helper
ls -l /usr/lib64/qt6/plugins/plasma/kcms/systemsettings/kcm_altstorage.so
