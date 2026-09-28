#!/bin/sh
# Спрятать из меню Plasma приложения, оставшиеся от Phosh и бесполезные под
# Plasma, и версии GNOME там, где есть такая же программа KDE (выбор
# пользователя 28.09.2026). От root. Пакеты не трогаются: в
# /usr/local/share/applications (в XDG_DATA_DIRS он раньше /usr/share)
# кладётся копия ярлыка с NotShowIn=KDE; под Phosh всё видно как прежде.
# Вернуть приложение: удалить его копию из /usr/local/share/applications.
set -e
SRC=/usr/share/applications
DST=/usr/local/share/applications
# Настраивают Phosh или GNOME
PHOSH="org.alt.Tweaks org.altlinux.Tuner org.altlinux.Foldy rygel-preferences"
# Дубли, у которых оставлена версия KDE: Kalk, KClock, KWeather,
# QMLKonsole, Calindori, KRecorder, Koko. Snapshot (камера GNOME) заменён
# plasma-camera: через PipeWire он открывает камеры параллельно, а на 6T
# они работают только по одной (общий csid0), и поток не запускается
DUPES="org.gnome.Calculator org.gnome.clocks org.gnome.Weather org.gnome.Console
org.gnome.Calendar app.drey.Vocalis org.gnome.Loupe
org.gnome.Snapshot"
mkdir -p $DST
for id in $PHOSH $DUPES; do
	f=$SRC/$id.desktop
	[ -f $f ] || { echo "нет $f, пропускаю"; continue; }
	cp $f $DST/$id.desktop
	if grep -q "^NotShowIn=" $DST/$id.desktop; then
		grep -q "^NotShowIn=.*KDE;" $DST/$id.desktop ||
			sed -i '0,/^NotShowIn=/s/^NotShowIn=\(.*\)$/NotShowIn=\1KDE;/' $DST/$id.desktop
	else
		sed -i '0,/^\[Desktop Entry\]$/s//[Desktop Entry]\nNotShowIn=KDE;/' $DST/$id.desktop
	fi
	echo "спрятан $id"
done
