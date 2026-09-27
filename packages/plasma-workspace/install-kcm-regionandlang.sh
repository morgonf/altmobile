#!/bin/sh
T=/usr/lib64/qt6/plugins/plasma/kcms/systemsettings/kcm_regionandlang.so
N=/home/altlinux/RPM/BUILD/plasma-workspace-6.7.5/BUILD/bin/plasma/kcms/systemsettings/kcm_regionandlang.so
[ -f $T.orig ] || cp -a $T $T.orig
strip --strip-debug -o /tmp/kcm_regionandlang.so $N
install -m 755 /tmp/kcm_regionandlang.so $T
ls -l $T $T.orig
