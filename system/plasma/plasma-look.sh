#!/bin/sh
# Внешний вид Plasma Mobile под экран OnePlus 6T (6,41", 1080x2340, ~400 dpi).
# Запуск от пользователя внутри сеанса. Подобрано 27 сентября 2026.
# Масштаб 3: логически 360x780. Пробовали 2.75 ради ширины, пользователю
# шрифт стал некомфортно мелким; налезание и многоточия лечатся переносом
# слов в самих модулях, а не уменьшением. Больше 3 не стоит, иначе
# приложения не влезают по ширине.
kscreen-doctor output.DSI-1.scale.3
# Шрифт Plasma по умолчанию 10 pt, для телефона мелко. От него отмеряется
# весь интерфейс Kirigami. 12 pt оказалось слишком много: подписи в ящике
# приложений наезжали друг на друга.
# Семейство PT Root UI (пакет fonts-ttf-PT-Root-UI): интерфейсный шрифт
# ParaType с исконной кириллицей, выбран пользователем 27.09.2026 для темы
# ALT. Статья TypeType не подошла, все её шрифты коммерческие.
# Моноширинный остаётся Noto Sans Mono.
F="PT Root UI"
K="kwriteconfig6 --file kdeglobals --group General --key"
$K font "$F,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
$K menuFont "$F,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
$K toolBarFont "$F,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
$K smallestReadableFont "$F,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
$K fixed "Noto Sans Mono,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
# Заголовок окна (kdeglobals [WM] activeFont): жирный того же семейства
kwriteconfig6 --file kdeglobals --group WM --key activeFont "$F,11,-1,5,700,0,0,0,0,0,0,0,0,0,0,1"
# Приложения GTK: то же семейство и размер, что у Plasma (раньше от Phosh
# осталось Adwaita Sans 14, шрифты в приложениях были разнобойными).
# Hack в системе нет, fontconfig подставлял вместо него Noto Sans.
G="gsettings set org.gnome.desktop.interface"
$G font-name "$F 11"
$G document-font-name "$F 11"
$G monospace-font-name "Noto Sans Mono 11"
gsettings set org.gnome.desktop.wm.preferences titlebar-font "$F Bold 11"
# Значки Folio 72 при масштабе 3 (при 2.75 нужно 82, физически то же):
# в ящике 3 столбца вместо 4 (столбцы считаются как
# ширина / (значок + отступы)), просьба пользователя. Ключ в группе Folio
# контейнера, как в foliosettings.cpp (умолчание 48). Пишется при остановленной
# оболочке, иначе она перезапишет файл при выходе.
systemctl --user stop plasma-plasmashell.service
kwriteconfig6 --file plasma-org.kde.plasma.mobileshell-appletsrc \
	--group Containments --group 1 --group Folio --key delegateIconSize 72
systemctl --user start plasma-plasmashell.service
