#!/bin/sh
# Русские каталоги, которых нет в пакетах: kcm_navigation (модуль не отдаёт
# строки переводчикам), интеграция с Waydroid и быстрые настройки «Экран» и
# Waydroid (в plasma-mobile 6.7.5 есть немецкий, но нет русского). От root,
# из каталога со скриптом.
cd "$(dirname "$0")"
T=/usr/share/locale/ru/LC_MESSAGES
for po in *.ru.po; do
	d=${po%.ru.po}
	msgfmt --check -o "$T/$d.mo" "$po" && echo "$d"
done
