#!/bin/sh
# plasma-keyboard 6.7.5: кнопка языка сразу переключает на следующий язык,
# без всплывающего списка. От root, оригинал сохраняется как .orig.
# Стиль Breeze из пакета включает languagePopupListEnabled (в Qt Virtual
# Keyboard по умолчанию выключено), и при двух языках каждое нажатие
# открывало меню выбора. После установки: pkill -x plasma-keyboard
# (KWin запустит клавиатуру заново).
set -e
F=/usr/lib64/qt6/qml/QtQuick/VirtualKeyboard/Styles/Breeze/style.qml
[ -f $F.orig ] || cp -a $F $F.orig
sed -i 's/^    languagePopupListEnabled: true$/    languagePopupListEnabled: false/' $F
grep -q '^    languagePopupListEnabled: false$' $F
