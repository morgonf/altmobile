#!/bin/sh
# Установка страницы «Доступ по SSH» от root: модуль, помощник KAuth
# org.altmobile.ssh (служба D-Bus, политика и действия polkit)
B=/home/altlinux/alt-settings/kcm_altssh
set -e
cd $B/build
SO=$(find . -name kcm_altssh.so | head -1)
strip --strip-debug -o /tmp/kas.tmp "$SO"
install -m 644 /tmp/kas.tmp /usr/lib64/qt6/plugins/plasma/kcms/systemsettings/kcm_altssh.so
rm -f /tmp/kas.tmp
# Помощник и его файлы ставит cmake, кроме модуля (он уже на месте)
cmake --install helper
ls -l /usr/lib64/qt6/plugins/plasma/kcms/systemsettings/kcm_altssh.so
