#!/bin/sh
# Очередь сборки RPM на телефоне: build-queue.sh ПАКЕТ... (от пользователя).
# Спецификация и патчи каждого пакета в ~/altmobile-pkg/<пакет>/. Журналы
# ~/queue-<пакет>.log, итог в ~/queue.log. Запускать одной службой
# systemd-run --user вместе со сторожами build-thermal-guard.sh и
# batt-guard.sh: заморозка службы останавливает и текущую сборку.
# Как в hasher: /usr/bin раньше /bin, иначе в скрипты попадает #!/bin/python3,
# а apt такого пути не знает
export PATH=/usr/bin:/usr/sbin:/bin:/sbin:$PATH
S=$(rpm --eval %_sourcedir)
for N in "$@"; do
	D=$HOME/altmobile-pkg/$N
	cp "$D"/*.patch "$D"/*.po "$S"/ 2>/dev/null
	echo "$(date +%T) $N начало" >> ~/queue.log
	if rpmbuild -ba --define "_smp_mflags -j2" --define "__ubt_branch_id M110" "$D/$N.spec" > ~/queue-$N.log 2>&1; then
		echo "$(date +%T) $N готов: $(grep -c '^Wrote' ~/queue-$N.log) файлов" >> ~/queue.log
	else
		echo "$(date +%T) $N ОШИБКА: $(grep -E 'error|ошибка' ~/queue-$N.log | tail -1)" >> ~/queue.log
	fi
done
echo "$(date +%T) очередь закончена" >> ~/queue.log
