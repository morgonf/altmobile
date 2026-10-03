#!/bin/sh
# Сборка RPM plasma-settings на телефоне, от пользователя. В %_sourcedir
# нужны plasma-settings-26.08.1.tar и патчи (кладутся этим скриптом).
set -e
D=$(dirname "$(readlink -f "$0")")
S=$(rpm --eval %_sourcedir); P=$(rpm --eval %_specdir)
mkdir -p "$S" "$P"
cp "$D"/*.patch "$S"/
cp "$D/plasma-settings.spec" "$P"/
exec rpmbuild -ba --define "_smp_mflags -j2" "$P"/plasma-settings.spec
