#!/bin/sh
# Установка темы ALT Mobile в систему, от root. Глобальные темы
# org.altlinux.mobile (тёмная, по умолчанию) и org.altlinux.mobile.light,
# обои пакетом ALTMobile, цветовые схемы, значки ALT. Применяет их к сеансу
# apply-alt-theme.sh от пользователя. Тему по умолчанию закрепляет
# plasma-mobile-envmanager (packages/plasma-mobile/envmanager-alt-lnf.patch),
# поэтому при пустых обоях Plasma берёт ALTMobile, а не Next.
#
# Картинки из образа ALT Mobile, не принадлежащие пакетам
# (/usr/share/wallpapers/alt-mobile), убираются из выбора обоев в
# /usr/share/alt-mobile/hidden-wallpapers. Вернуть можно обратным mv.
set -e
cd "$(dirname "$0")"
S=/usr/share
install -d $S/plasma/look-and-feel $S/wallpapers $S/color-schemes $S/icons
for p in look-and-feel/*; do
	rm -rf "$S/plasma/$p"
	cp -r "$p" $S/plasma/look-and-feel/
done
rm -rf $S/wallpapers/ALTMobile
cp -r wallpapers/ALTMobile $S/wallpapers/
install -m 644 ALTMobile.colors ALTMobileDark.colors $S/color-schemes/
rm -rf $S/icons/ALT
cp -r icons/ALT $S/icons/
chmod -R u=rwX,go=rX $S/plasma/look-and-feel/org.altlinux.mobile* $S/wallpapers/ALTMobile $S/icons/ALT
if [ -d $S/wallpapers/alt-mobile ]; then
	install -d $S/alt-mobile/hidden-wallpapers
	mv $S/wallpapers/alt-mobile $S/alt-mobile/hidden-wallpapers/
fi
ls -d $S/plasma/look-and-feel/org.altlinux.mobile* $S/wallpapers/*
