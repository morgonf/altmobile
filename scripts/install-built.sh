#!/bin/sh
# Установка всех собранных на телефоне пакетов ALT Mobile одним шагом, от
# root: локальный репозиторий, apt-get install, уборка временных подмен,
# проверка rpm -V. kwin и plasma-workspace меняются под работающим сеансом,
# поэтому после скрипта перезагрузка (reboot), а не продолжение работы.
# install-built.sh [-n]   -n: только показать, что будет поставлено
set -e
export PATH=/usr/bin:/usr/sbin:/bin:/sbin
D=$(dirname "$(readlink -f "$0")")
DRY=
[ "$1" = "-n" ] && DRY=-s

sh "$D/local-repo.sh"
apt-get update >/dev/null

# Наши пакеты: всё, что есть в локальном репозитории и уже стоит в системе
# (другие подпакеты, например -devel, не тянем), плюс новые для нас
R=/var/lib/altmobile/repo
PKGS=$(for f in $R/aarch64/RPMS.altmobile/*.rpm $R/noarch/RPMS.altmobile/*.rpm; do
	[ -f "$f" ] || continue
	n=$(rpm -qp --nosignature --qf '%{NAME}' "$f" 2>/dev/null)
	rpm -q "$n" >/dev/null 2>&1 && echo "$n"
done | sort -u)
echo "Ставится: $PKGS"
apt-get install -y $DRY $PKGS

[ -n "$DRY" ] && exit 0

# Временные подмены, которые пакеты заменили (docs/install.md)
find /usr/lib64/qt6/qml/org/kde/plasma/private/mobileshell \
	/usr/share/plasma/shells/org.kde.plasma.mobileshell -name '*.pre-lsn' -delete

echo "Проверка rpm -V (конфигурационные файлы помечены c):"
for n in $PKGS; do
	out=$(rpm -V "$n" 2>&1 | grep -v ' c /' || true)
	[ -n "$out" ] && echo "$n:" && echo "$out"
done
echo "Готово. Перезагрузите телефон."
