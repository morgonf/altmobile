#!/bin/sh
# Замер утечки из разговорного динамика в микрофон собственным тоном.
#
# Профиль карты переводится в разговорный, тон 1 кГц уровнем минус 12 дБ подаётся
# в разговорный динамик, одновременно пишется микрофонный тракт. Затем то же
# самое с перерезанным на уровне кодека микрофоном, чтобы отличить утечку по
# воздуху от электрической петли.
#
# Аргумент: cut, если надо перерезать микрофон.

CARD=alsa_card.platform-sound
CUT="$1"

pactl set-card-profile $CARD "Voice Call" 2>&1
sleep 2

SINK=$(pactl list short sinks 2>/dev/null | awk '/Voice_Call/{print $2; exit}')
SRC=$(pactl list short sources 2>/dev/null | awk '/Voice_Call.*Mic/{print $2; exit}')
echo "приёмник: $SINK"
echo "источник: $SRC"

# уровень цифрового и аналогового усиления на момент замера
for n in "RX0 Digital Volume" "EAR PA Volume" "ADC4 Volume" "DEC7 Volume" "ADC MUX7"; do
	printf "  %-20s = %s\n" "$n" "$(amixer -c 0 cget name="$n" 2>/dev/null | grep -m1 ': values=' | sed 's/.*values=//')"
done

if [ "$CUT" = cut ]; then
	echo "перерезаю микрофон: ADC MUX7 в ZERO"
	amixer -c 0 cset name='ADC MUX7' 0 >/dev/null 2>&1
	printf "  ADC MUX7 теперь = %s\n" "$(amixer -c 0 cget name='ADC MUX7' | grep -m1 ': values=' | sed 's/.*values=//')"
	OUT=/tmp/q6tone-cut.wav
else
	OUT=/tmp/q6tone.wav
fi

pactl set-sink-volume "$SINK" 100% 2>/dev/null
pactl set-source-volume "$SRC" 100% 2>/dev/null

timeout 9 parecord -d "$SRC" --format=s16le --rate=48000 --channels=1 --file-format=wav "$OUT" &
REC=$!
sleep 1
paplay -d "$SINK" /tmp/tone1k.wav 2>&1 &
PLAY=$!
wait $REC
kill $PLAY 2>/dev/null

# микрофон обратно
amixer -c 0 cset name='ADC MUX7' 1 >/dev/null 2>&1
ls -l "$OUT"
