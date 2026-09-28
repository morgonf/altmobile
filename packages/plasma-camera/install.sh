#!/bin/sh
# plasma-camera с патчем и русским каталогом, от root. Сборка заранее в $B.
set -e
cd "$(dirname "$0")"
B=${1:-/home/altlinux/plasma-camera/build}
F=/usr/bin/plasma-camera
[ -f $F.orig ] || cp -a $F $F.orig
install -m 755 $B/bin/plasma-camera $F
M=/usr/share/locale/ru/LC_MESSAGES/plasma-camera.mo
[ -f $M.orig ] || cp -a $M $M.orig
python3 mo-merge.py $M.orig plasma-camera.ru-add.po /tmp/plasma-camera.mo
install -m 644 /tmp/plasma-camera.mo $M
