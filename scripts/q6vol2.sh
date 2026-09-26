#!/bin/sh
# Тонкая настройка усилений разговорного тракта.
#
# Громкость добавляется аналоговым каскадом EAR PA, а не цифровым усилением,
# потому что цифровое выше нуля обрезает сигнал и ломает эхоподавитель.
# Шаг EAR PA равен 1,5 дБ, всего пять положений от 0 до 4.
#
# Микрофон поднимается цифровым DEC7, потому что собеседник слышал тихо.

PATH=/sbin:/usr/sbin:$PATH
export PATH
F="/usr/share/alsa/ucm2/conf.d/sdm845/OnePlus 6T.conf"

EARPA=2		# плюс 3 дБ
DEC7=90		# плюс 6 дБ
ADC4=16		# как задаёт профиль

echo "== правлю исполняемый файл профиля"
[ -f "$F.orig" ] || cp -a "$F" "$F.orig"
sed -i "s/cset \"name='EAR PA Volume' [0-9]*\"/cset \"name='EAR PA Volume' $EARPA\"/" "$F"
sed -i "s/cset \"name='DEC7 Volume' [0-9]*\"/cset \"name='DEC7 Volume' $DEC7\"/" "$F"
grep -nE "EAR PA Volume|DEC7 Volume|ADC4 Volume" "$F" | sed 's/^/  /'

echo
echo "== выставляю сразу"
amixer -c 0 cset name='EAR PA Volume' $EARPA >/dev/null 2>&1
amixer -c 0 cset name='DEC7 Volume' $DEC7 >/dev/null 2>&1
amixer -c 0 cset name='ADC4 Volume' $ADC4 >/dev/null 2>&1
amixer -c 0 cset name='RX0 Digital Volume' 84 >/dev/null 2>&1

for n in "RX0 Digital Volume" "EAR PA Volume" "ADC4 Volume" "DEC7 Volume"; do
	printf "  %-22s = %s\n" "$n" "$(amixer -c 0 cget name="$n" | grep -m1 ': values=' | sed 's/.*values=//')"
done
