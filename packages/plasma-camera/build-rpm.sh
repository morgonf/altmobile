#!/bin/sh
# Сборка RPM plasma-camera 2.1.1-alt2.mobile2 на телефоне, от пользователя.
# В %_sourcedir (у ALT ~/RPM/SOURCES) нужен тарбол plasma-camera-2.1.1.tar (каталог
# plasma-camera-2.1.1/ из gear ALT), патчи, .po и mo-merge.py кладутся
# этим скриптом. Сборка в два потока: в четыре не хватает MemoryMax.
set -e
D=$(dirname "$(readlink -f "$0")")
S=$(rpm --eval %_sourcedir); P=$(rpm --eval %_specdir)
mkdir -p "$S" "$P"
cp "$D"/*.patch "$D/plasma-camera.ru-add.po" "$D/mo-merge.py" "$S"/
cp "$D/plasma-camera.spec" "$P"/
exec rpmbuild -ba --define "_smp_mflags -j2" "$P"/plasma-camera.spec
