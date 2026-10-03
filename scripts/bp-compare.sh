#!/bin/sh
# Сверка: дерево по нашей спецификации (rpmbuild -bp) против рабочего дерева
# ~/RPM/BUILD/<пакет>-<версия>, из которого собраны установленные файлы.
# bp-compare.sh ПАКЕТ КАТАЛОГ_С_spec_И_ПАТЧАМИ
set -e
N=$1; D=$2
S=$(rpm --eval %_sourcedir)
cp "$D"/*.patch "$S"/
T=/var/tmp/bp-$N; rm -rf $T; mkdir -p $T
rpmbuild -bp --nodeps --define "_builddir $T" --define "__ubt_branch_id M110" "$D/$N.spec" > $T.log 2>&1 || { tail -5 $T.log; exit 1; }
NEW=$(ls -d $T/*/ | head -1); OLD=$HOME/RPM/BUILD/$(basename $NEW)
diff -r -q -x BUILD -x '*.orig' -x '*.rej' -x '*~' "$OLD" "$NEW" | sed "s|$HOME/RPM/BUILD/||; s|$T/||" | head -30
echo "== $N сверено"
rm -rf $T
