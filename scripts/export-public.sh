#!/bin/sh
# Очищенная копия репозитория для публикации (github.com/morgonf/altmobile).
# Запуск: scripts/export-public.sh КАТАЛОГ
# Клонирует текущий репозиторий в КАТАЛОГ и переписывает всю историю.
# Из каждого коммита удаляются калибровочные данные, снятые с телефона
# (проприетарная ACDB производителя). Домашние сетевые данные заменяются
# обезличенными: адрес телефона, BSSID точки доступа, имя сети Wi‑Fi.
# Затем проверяет, что в истории ничего из этого не осталось.
# Сами значения в репозиторий не входят, они лежат в scripts/export-private.sed
# (в .gitignore), по одному правилу sed на строку
# в виде s/ИСКОМОЕ/ЗАМЕНА/g. Образец в scripts/export-private.sed.example.
set -e
SRC=$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)
SED=$SRC/scripts/export-private.sed
[ -f "$SED" ] || { echo "нет $SED" >&2; exit 1; }
# Искомое из правил s/ИСКОМОЕ/.../ одной регуляркой для grep
PAT=$(sed -nE 's|^s/([^/]*)/.*|\1|p' "$SED" | paste -sd'|')
DST=${1:?укажите каталог для очищенной копии}
[ -e "$DST" ] && { echo "$DST уже существует" >&2; exit 1; }

git clone -q --no-local "$SRC" "$DST"
cd "$DST"

BLOBS="kernel/cal-ecns-on.bin kernel/cal-tx-on.bin kernel/cal-v2-factory.bin
kernel/cal-v2-final.bin kernel/ecns-10e61-factory.hex
kernel/q6voice-cal-ecns1.bin system/ecns-10e61.hex"

FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --tree-filter "
rm -f $(echo $BLOBS)
grep -rlIE '$PAT' . 2>/dev/null |
	grep -v '^\./\.git/' |
	xargs -r sed -i -E -f '$SED'
" -- --all >/dev/null

git for-each-ref --format='%(refname)' refs/original | xargs -r -n1 git update-ref -d
git remote remove origin
git reflog expire --expire=now --all
git gc -q --prune=now --aggressive

# Проверка по всей истории
LEFT=$(git log --all --name-only --format= | sort -u | grep -E '\.(bin|hex)$' || true)
[ -z "$LEFT" ] || { echo "остались файлы: $LEFT" >&2; exit 1; }
for rev in $(git rev-list --all); do
	git grep -qE "$PAT" "$rev" &&
		{ echo "остались сетевые данные в $rev" >&2; exit 1; }
done
echo "готово: $DST, коммитов $(git rev-list --all | wc -l)"
