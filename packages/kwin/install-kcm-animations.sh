#!/bin/sh
T=/usr/lib64/qt6/plugins/plasma/kcms/systemsettings/kcm_animations.so
N=/home/altlinux/RPM/BUILD/kwin-6.7.5/BUILD/bin/plasma/kcms/systemsettings/kcm_animations.so
[ -f $T.orig ] || cp -a $T $T.orig
strip --strip-debug -o /tmp/kcm_animations.so $N
install -m 644 /tmp/kcm_animations.so $T
ls -l $T $T.orig > /tmp/.private/altlinux/animinst.log 2>&1
chown altlinux /tmp/.private/altlinux/animinst.log
