#!/bin/sh
# Установка пересобранного модуля настроек поверх штатного, с копией .orig.
# kcm-install.sh <собранный .so> — от root.
N=$1
T=/usr/lib64/qt6/plugins/plasma/kcms/systemsettings/$(basename $N)
L=/tmp/.private/altlinux/kcminst.log
[ -f $T.orig ] || cp -a $T $T.orig
strip --strip-debug -o /tmp/$(basename $N) $N
install -m 644 /tmp/$(basename $N) $T
ls -l $T $T.orig > $L 2>&1
chown altlinux $L
