#!/bin/sh
# Установка пересобранных частей plasma-mobile поверх штатных, с копией .orig.
# От root. Перезапуск оболочки и KWin (переключатель задач) после установки.
B=/home/altlinux/RPM/BUILD/plasma-mobile-6.7.5
L=/tmp/.private/altlinux/pminst.log
put() { # $1 источник, $2 цель, $3 права
	[ -f "$2.orig" ] || cp -a "$2" "$2.orig"
	case "$1" in *.so) strip --strip-debug -o /tmp/pm.tmp "$1";; *) cp "$1" /tmp/pm.tmp;; esac
	install -m "$3" /tmp/pm.tmp "$2"
	ls -l "$2" >> $L
}
: > $L
put $B/BUILD/components/mobileshell/libmobileshellplugin.so /usr/lib64/qt6/qml/org/kde/plasma/private/mobileshell/libmobileshellplugin.so 644
put $B/BUILD/bin/plasma/applets/org.kde.plasma.mobile.homescreen.folio.so /usr/lib64/qt6/plugins/plasma/applets/org.kde.plasma.mobile.homescreen.folio.so 644
put $B/kwin/mobiletaskswitcher/package/contents/ui/TaskSwitcher.qml /usr/share/kwin/effects/mobiletaskswitcher/contents/ui/TaskSwitcher.qml 644
# Глобальная тема ALT Mobile вместо org.kde.breeze.mobile (envmanager-alt-lnf.patch)
put $B/BUILD/bin/plasma-mobile-envmanager /usr/bin/plasma-mobile-envmanager 755
chown altlinux $L
