#!/bin/sh
# Установка пересобранного kscreenlocker_greet поверх штатного, с копией
# .orig. От root. Работающий экран блокировки не трогается, новый файл
# подхватит следующая блокировка. Откат: cp -a /usr/libexec/kscreenlocker_greet.orig /usr/libexec/kscreenlocker_greet
B=/home/altlinux/RPM/BUILD/kscreenlocker-6.7.5/BUILD/bin/kscreenlocker_greet
T=/usr/libexec/kscreenlocker_greet
[ -f $B ] || B=$(find /home/altlinux/RPM/BUILD/kscreenlocker-6.7.5/BUILD -name kscreenlocker_greet -type f | head -1)
[ -f $T.orig ] || cp -a $T $T.orig
strip --strip-debug -o /tmp/ksl.tmp "$B"
install -m 755 /tmp/ksl.tmp $T
rm -f /tmp/ksl.tmp
ls -l $T $T.orig
