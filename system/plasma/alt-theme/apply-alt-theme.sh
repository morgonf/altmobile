#!/bin/sh
# Тема ALT для Plasma Mobile на OnePlus 6T: цвета, значки, обои по брендбуку
# Базальт СПО 3.8.1 (www.basealt.ru/mediakit). Запуск от пользователя внутри
# сеанса, из каталога со скриптом. Шрифт PT Root UI задаёт ../plasma-look.sh.
#
# Цвета (брендбук, с. 6-7, 24): акцент #f5911f «Альт Мобильный», текст графит
# #333333, фон окон белый дымчатый #f6f6f6, серые нейтральные. Отступления
# ради читаемости: ссылки тёмно-оранжевые #c46200 (синий брендбук запрещает,
# а #f5911f на белом даёт контраст 2.4:1), текст на выделении графитом, а не
# белым. Значок «Домой» (start-here-kde) заменён знаком «Альт Мобильный»:
# гекс с вырезанной рамкой телефона, одноцветный, перекрашивается под тему.
# Обои: WP_1 из медиакита, CMYK переведён в sRGB по встроенному профилю,
# вертикальный кадр 1080x2340.
set -e
cd "$(dirname "$0")"
D=${XDG_DATA_HOME:-$HOME/.local/share}
mkdir -p "$D/icons" "$D/color-schemes" "$D/wallpapers"
cp -r icons/ALT "$D/icons/"
cp ALTMobile.colors "$D/color-schemes/"
cp alt-mobile-wallpaper.jpg "$D/wallpapers/"

# Акцент из обоев иначе перекрашивает схему обратно в цвета Breeze
kwriteconfig6 --file kdeglobals --group General --key accentColorFromWallpaper false
kwriteconfig6 --file kdeglobals --group General --key AccentColor --delete
plasma-apply-colorscheme ALTMobile 2>&1 | grep -v -e xrdb -e xcb_connect || true
/usr/libexec/plasma-changeicons ALT

# Приложения GTK (Firefox, калькулятор и др.) в тех же цветах и шрифте:
# нужен пакет kde-gtk-config (модуль kded gtkconfig переносит схему Plasma
# в ~/.config/gtk-3.0/colors.css). Тема GTK Breeze вместо Adwaita от Phosh,
# prefer-dark от Phosh снят. После смены схемы модуль пишет цвета заново.
G="gsettings set org.gnome.desktop.interface"
$G gtk-theme Breeze
$G color-scheme default
$G icon-theme ALT
busctl --user call org.kde.kded6 /kded org.kde.kded6 loadModule s gtkconfig >/dev/null
plasma-apply-colorscheme BreezeLight >/dev/null 2>&1
plasma-apply-colorscheme ALTMobile 2>&1 | grep -v -e xrdb -e xcb_connect || true

plasma-apply-wallpaperimage "$D/wallpapers/alt-mobile-wallpaper.jpg"
G="kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key"
$G Image "file://$D/wallpapers/alt-mobile-wallpaper.jpg"
$G PreviewImage "file://$D/wallpapers/alt-mobile-wallpaper.jpg"

# Значок в кнопке навигации кэшируется, без перезапуска оболочки он прежний
systemctl --user restart plasma-plasmashell.service
