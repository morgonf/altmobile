#!/bin/sh
# Запись микрофонного тракта во время разговора.
#
# В профиле звонка поток с SLIMBUS_0_TX заведён и на устройство захвата
# MultiMedia2, поэтому пишется ровно тот сигнал, который уходит в процессор,
# то есть уже после ADC4 и DEC7.
#
# Использование: q6rec.sh <секунд> <файл>

SEC=${1:-6}
OUT=${2:-/tmp/q6mic.raw}

echo "усиления на момент записи:"
for n in "ADC4 Volume" "DEC7 Volume" "RX0 Digital Volume" "EAR PA Volume"; do
	printf "  %-20s = %s\n" "$n" "$(amixer -c 0 cget name="$n" | grep -m1 ': values=' | sed 's/.*values=//')"
done

echo "пишу $SEC с в $OUT"
if arecord -D hw:0,1 -f S16_LE -r 48000 -c 1 -d "$SEC" -t raw "$OUT" 2>/tmp/q6rec.err; then
	echo "записано arecord"
else
	echo "arecord не смог, причина:"
	cat /tmp/q6rec.err
	echo "пробую pw-record"
	timeout $((SEC + 3)) pw-record --target=0 --rate=48000 --channels=1 --format=s16 "$OUT.wav" 2>/tmp/q6rec2.err &
	sleep "$SEC"
	kill %1 2>/dev/null
	ls -l "$OUT.wav" 2>&1
fi
ls -l "$OUT" 2>&1
chmod 644 "$OUT" "$OUT.wav" 2>/dev/null
