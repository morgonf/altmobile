#!/bin/sh
# Сборка RPM plasma-camera 2.1.1-alt2.mobile1 на телефоне, от пользователя.
# В ~/rpmbuild/SOURCES нужен тарбол plasma-camera-2.1.1.tar (каталог
# plasma-camera-2.1.1/ из gear ALT), патчи, .po и mo-merge.py кладутся
# этим скриптом. Сборка в два потока: в четыре не хватает MemoryMax.
set -e
D=$(dirname "$(readlink -f "$0")")
mkdir -p ~/rpmbuild/SOURCES ~/rpmbuild/SPECS
cp "$D"/*.patch "$D/plasma-camera.ru-add.po" "$D/mo-merge.py" ~/rpmbuild/SOURCES/
cp "$D/plasma-camera.spec" ~/rpmbuild/SPECS/
exec rpmbuild -ba --define "_smp_mflags -j2" ~/rpmbuild/SPECS/plasma-camera.spec
