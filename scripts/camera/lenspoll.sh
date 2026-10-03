#!/bin/sh
# Опрос положения линзы IMX519: lenspoll.sh секунды
end=$(( $(date +%s) + $1 ))
while [ $(date +%s) -lt $end ]; do
  printf "%s %s\n" "$(date +%T.%N | cut -c1-12)" "$(v4l2-ctl -d /dev/v4l-subdev${2:-20} -C focus_absolute 2>&1)"
  sleep 0.05
done
