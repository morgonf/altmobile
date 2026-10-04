#!/bin/sh
# Локальный репозиторий apt из пакетов ALT Mobile, собранных на телефоне.
# Запуск от root: local-repo.sh [каталог RPMS]. По умолчанию берётся
# ~altlinux/RPM/RPMS (aarch64 и noarch). Из нескольких сборок одного пакета
# остаётся самая новая (по времени сборки), отладочные пакеты пропускаются.
# После запуска наши пакеты ставятся и обновляются обычным apt-get:
#   apt-get update && apt-get install plasma-camera
# Выпуски вида alt1.mobileN новее одноимённых alt1 из Sisyphus, а от более
# новых версий из Sisyphus их держит RPM::Hold (system/apt).
# Нужен пакет apt-repo-tools (genbasedir).
set -e
SRC=${1:-/home/altlinux/RPM/RPMS}
R=/var/lib/altmobile/repo
LIST=/etc/apt/sources.list.d/altmobile.list

command -v genbasedir >/dev/null || { echo "нет genbasedir: apt-get install apt-repo-tools" >&2; exit 1; }

for A in aarch64 noarch; do
	D=$R/$A/RPMS.altmobile
	rm -rf "$D"
	mkdir -p "$D" "$R/$A/base"
	[ -d "$SRC/$A" ] || continue
	# Самая новая сборка каждого имени
	for f in "$SRC/$A"/*.rpm; do
		[ -f "$f" ] || continue
		rpm -qp --nosignature --qf '%{NAME} %{BUILDTIME} ' "$f" 2>/dev/null
		echo "$f"
	done | grep -v -- '-debuginfo ' | sort -k1,1 -k2,2nr | awk '!seen[$1]++ {print $3}' |
	while read -r f; do
		ln "$f" "$D/" 2>/dev/null || cp -p "$f" "$D/"
	done
	genbasedir --topdir="$R" --bloat "$A" altmobile >/dev/null
	echo "$A: $(ls "$D" | wc -l) пакетов"
done

cat > "$LIST" <<EOF
# ALT Mobile для OnePlus 6T: пакеты, собранные на телефоне (scripts/local-repo.sh)
rpm file:$R aarch64 altmobile
rpm file:$R noarch altmobile
EOF
echo "источник записан в $LIST, дальше apt-get update"
