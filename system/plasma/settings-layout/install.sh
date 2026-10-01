#!/bin/sh
# Раскладка групп «Настроек» ALT Mobile, от root. Нужен plasma-settings с
# патчем plasma-settings-alt-layout.patch (install-plasma-settings.sh).
set -e
cd "$(dirname "$0")"
install -d /usr/share/alt-mobile/settings-categories
rm -f /usr/share/alt-mobile/settings-categories/*.desktop
install -m 644 categories/*.desktop /usr/share/alt-mobile/settings-categories/
install -m 644 plasma-settings-alt-layoutrc /etc/xdg/plasma-settings-alt-layoutrc
B=/home/altlinux/RPM/BUILD/plasma-settings-26.08.1/BUILD/bin/plasma-settings
if [ -f "$B" ]; then
	[ -f /usr/bin/plasma-settings.orig ] || cp -a /usr/bin/plasma-settings /usr/bin/plasma-settings.orig
	strip --strip-debug -o /tmp/ps.tmp "$B"
	install -m 755 /tmp/ps.tmp /usr/bin/plasma-settings
	rm -f /tmp/ps.tmp
fi
ls -l /usr/bin/plasma-settings /etc/xdg/plasma-settings-alt-layoutrc
