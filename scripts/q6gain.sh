#!/bin/sh
# Сравнение аналогового усиления микрофона: тон 1 кГц минус 12 дБ в разговорный
# динамик, запись микрофонного тракта при ADC4 Volume 20 (громкость источника
# PipeWire 100%) и при заводском значении 12 из mixer_paths_tavil.xml.
# Запуск от пользователя, звонка не нужно.

CARD=alsa_card.platform-sound
OLD=$(pactl list cards | awk '/Активный профиль|Active Profile/{sub(/.*: /,""); print; exit}')
pactl set-card-profile $CARD "Voice Call"
sleep 2
SINK=$(pactl list short sinks | awk '/Voice_Call/{print $2; exit}')
SRC=$(pactl list short sources | awk '/Voice_Call.*Mic/{print $2; exit}')
pactl set-sink-volume "$SINK" 100%
pactl set-source-volume "$SRC" 100%

for g in 20 12; do
	amixer -c0 cset name='ADC4 Volume' $g >/dev/null
	for n in "RX0 Digital Volume" "EAR PA Volume" "ADC4 Volume" "DEC7 Volume"; do
		printf "  %-20s = %s\n" "$n" "$(amixer -c0 cget name="$n" | grep -m1 ': values=' | sed 's/.*values=//')"
	done
	timeout 7 parecord -d "$SRC" --format=s16le --rate=48000 --channels=1 --file-format=wav /tmp/q6gain-$g.wav &
	REC=$!
	sleep 1
	paplay -d "$SINK" /tmp/tone1k.wav &
	PLAY=$!
	wait $REC
	kill $PLAY 2>/dev/null
	echo "ADC4 $g: $(ls -l /tmp/q6gain-$g.wav)"
done
pactl set-source-volume "$SRC" 100%
[ -n "$OLD" ] && pactl set-card-profile $CARD "$OLD"
echo "профиль возвращён: $OLD"
