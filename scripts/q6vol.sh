#!/bin/sh
# Привести усиления разговорного тракта к задуманным значениям.
# Правится тот файл UCM, который действительно исполняется: точка входа лежит в
# conf.d, а не в OnePlus/fajita/fajita.conf, куда правки вносились раньше и
# оставались без действия.

PATH=/sbin:/usr/sbin:$PATH
export PATH
F="/usr/share/alsa/ucm2/conf.d/sdm845/OnePlus 6T.conf"

echo "== резервная копия"
[ -f "$F.orig" ] || { cp -a "$F" "$F.orig" && echo "  сохранена $F.orig"; }

if grep -q "EAR PA Volume" "$F"; then
	echo "  строка про EAR PA уже есть"
else
	# добавляем перед закрывающей скобкой BootSequence
	awk '
	  /^\]/ && !done && seen { print "\t"; print "\t# оконечный каскад разговорного динамика без усиления, против акустического эха"; print "\tcset \"name='"'"'EAR PA Volume'"'"' 0\""; done=1 }
	  /^BootSequence \[/ { seen=1 }
	  { print }
	' "$F" > "$F.new" && mv "$F.new" "$F" && echo "  строка добавлена"
fi

echo
echo "== BootSequence теперь"
sed -n '/^BootSequence/,/^\]/p' "$F"

echo
echo "== выставляю сразу, без перезагрузки"
amixer -c 0 cset name='EAR PA Volume' 0 >/dev/null 2>&1
amixer -c 0 cset name='RX0 Digital Volume' 84 >/dev/null 2>&1
for n in "EAR PA Volume" "RX0 Digital Volume" "ADC4 Volume" "DEC7 Volume"; do
	echo "  $n = $(amixer -c 0 cget name="$n" | grep -m1 ': values=' | sed 's/.*values=//')"
done
