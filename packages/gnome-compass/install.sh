#!/bin/sh
# Compass (gnome-compass 0.4.0) с направлением из iio-sensor-proxy, от root.
# Оригиналы сохраняются рядом с суффиксом .orig.
set -e
cd "$(dirname "$0")"
D=/usr/share/compass
for f in compass.py main.py; do
	[ -f $D/compass/$f.orig ] || cp -a $D/compass/$f $D/compass/$f.orig
	cp -a $D/compass/$f.orig $D/compass/$f
done
patch -p1 -d $D < gnome-compass-iio-sensor-proxy.patch
