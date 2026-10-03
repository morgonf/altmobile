#!/bin/sh
# Сборка RPM libcamera 0.7.2-alt1.mobile1 на телефоне, от пользователя.
# Нужны в ~/rpmbuild/SOURCES тарбол libcamera-0.7.2.tar (git archive
# --prefix=libcamera-0.7.2/ v0.7.2) и libcamera-0.7.2-altmobile.patch,
# спецификация рядом со скриптом. Сборочные зависимости проверяются
# rpmbuild. Запускать службой systemd-run --user со сторожем температуры
# scripts/build-thermal-guard.sh, в два потока.
set -e
D=$(dirname "$(readlink -f "$0")")
mkdir -p ~/rpmbuild/SOURCES ~/rpmbuild/SPECS
cp "$D/libcamera.spec" ~/rpmbuild/SPECS/
exec rpmbuild -ba --define "_smp_mflags -j2" ~/rpmbuild/SPECS/libcamera.spec
