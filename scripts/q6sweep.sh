#!/bin/sh
# Частотная характеристика пути «разговорный динамик -> нижний микрофон»:
# ступени тона 100..8000 Гц по секунде, уровень минус 12 дБ. Акустический путь
# через разговорный динамик на низких частотах почти глухой, электрическая
# наводка от частоты почти не зависит. Запуск от пользователя, без звонка.
# Аргумент: имя для записи (по умолчанию sweep).

NAME=${1:-sweep}
CARD=alsa_card.platform-sound
OLD=$(pactl list cards | awk '/Активный профиль|Active Profile/{sub(/.*: /,""); print; exit}')
pactl set-card-profile $CARD "Voice Call"
sleep 2
SINK=$(pactl list short sinks | awk '/Voice_Call/{print $2; exit}')
SRC=$(pactl list short sources | awk '/Voice_Call.*Mic/{print $2; exit}')
pactl set-sink-volume "$SINK" 100%
pactl set-source-volume "$SRC" 100%
for n in "RX0 Digital Volume" "EAR PA Volume" "ADC4 Volume" "DEC7 Volume"; do
	printf "  %-20s = %s\n" "$n" "$(amixer -c0 cget name="$n" | sed -n 's/.*: values=//p')"
done
timeout 14 parecord -d "$SRC" --format=s16le --rate=48000 --channels=1 --file-format=wav /tmp/q6-$NAME.wav &
REC=$!
sleep 1
paplay -d "$SINK" /tmp/sweep.wav
wait $REC
[ -n "$OLD" ] && pactl set-card-profile $CARD "$OLD"
ls -l /tmp/q6-$NAME.wav
