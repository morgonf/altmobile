#!/bin/sh
# Экранная клавиатура: русский и английский, от пользователя. Без списка
# plasma-keyboard берёт системную раскладку, а модуль настроек на телефоне
# не показывается (см. packages/plasma-keyboard/README.md).
kwriteconfig6 --file plasmakeyboardrc --group General --key enabledLocales "ru_RU,en_US"
pkill -x plasma-keyboard || true
