#!/bin/sh
# Браузеры под экран OnePlus 6T (масштаб 3, логически 360 точек в ширину).
# От root. Проверено 27.09.2026.
#
# Chromium 154 под Wayland не сжимается уже ~500 точек: окно вылезает за
# край, вкладки, адресная строка и страница обрезаны. Флаг масштаба под
# Wayland умножается на масштаб композитора и делает только хуже. Под
# XWayland окно видит экран в физических пикселях (в «Экране» для X11 стоит
# «масштабирование средствами приложений»), и с масштабом 2.1 ширина 514
# точек: помещается целиком, шрифт чуть мельче системного.
# /etc/chromium/default в пакете помечен как файл настроек, обновление его
# не затирает.
F=/etc/chromium/default
sed -i "/# ALT Mobile, OnePlus 6T/,\$d" $F
cat >> $F <<'EOT'

# ALT Mobile, OnePlus 6T: через XWayland с масштабом 2.1, иначе окно шире
# экрана (минимальная ширина Chromium около 500 точек, экран 360)
# Без этой переменной /usr/bin/chromium дописывает --ozone-platform=wayland
# после наших флагов, и он побеждает
export CHROMIUM_DISABLE_WAYLAND=1
export CHROMIUM_FLAGS="$CHROMIUM_FLAGS --ozone-platform=x11 --force-device-scale-factor=2.1"
EOT
# Firefox 156 работает через Wayland и с mobile-config-prefs помещается,
# шире экрана было только окно «Сделать Firefox браузером по умолчанию».
cat > /usr/lib64/firefox/defaults/pref/alt-mobile.js <<'EOT'
// ALT Mobile, OnePlus 6T: окно вопроса о браузере по умолчанию шире экрана
pref("browser.shell.checkDefaultBrowser", false);
EOT
tail -4 $F
cat /usr/lib64/firefox/defaults/pref/alt-mobile.js
