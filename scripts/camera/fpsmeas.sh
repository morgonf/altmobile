#!/bin/sh
# Частота кадров IMX519 при заданном VBLANK, напрямую через V4L2.
# fpsmeas.sh ШИРИНА ВЫСОТА VBLANK...
W=$1; H=$2; shift 2
F="SRGGB10_1X10/${W}x${H}"
for n in "imx519 16-001a" msm_csiphy0 msm_csid0 msm_vfe0_rdi0; do
  media-ctl -d /dev/media0 -V "\"$n\":0[fmt:$F]" || exit 1
done
v4l2-ctl -d /dev/video0 --set-fmt-video=width=$W,height=$H,pixelformat=pRAA || exit 1
for vb in "$@"; do
  v4l2-ctl -d /dev/v4l-subdev19 -c vertical_blanking=$vb
  real=$(v4l2-ctl -d /dev/v4l-subdev19 -C vertical_blanking | cut -d" " -f2)
  t=$(v4l2-ctl -d /dev/video0 --verbose --stream-mmap=4 --stream-count=25 --stream-to=/dev/null 2>&1 | grep -o "ts: [0-9.]*" | awk "NR>5{n++; if(NR==6)a=\$2; b=\$2} END{printf \"%.3f\", (b-a)/(n-1)*1000}")
  echo "$W x $H vblank $real: $t ms"
done
