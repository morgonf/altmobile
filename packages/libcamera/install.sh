#!/bin/sh
# Установка libcamera 0.7.2 с патчами этого каталога поверх пакета ALT, от
# root. Сборка на телефоне заранее (см. README.md), дерево в $B.
# Оригиналы пакета сохраняются в $O (не рядом: ldconfig находит копию с тем
# же soname и может направить ссылку libcamera*.so.0.7 на неё).
# Откат: uninstall.sh.
set -e
B=${1:-/home/altlinux/libcamera-af/build}
O=/usr/lib64/libcamera-alt-orig
mkdir -p $O
put() { # $1 источник, $2 цель, $3 права
	b=$O/$(echo "$2" | tr / _)
	[ -f "$b" ] || cp -a "$2" "$b"
	install -m "$3" "$1" "$2"
}
L=/usr/lib64
put $B/src/libcamera/libcamera.so.0.7.2 $L/libcamera.so.0.7.2 755
put $B/src/libcamera/base/libcamera-base.so.0.7.2 $L/libcamera-base.so.0.7.2 755
# IPA подписан ключом, зашитым в эту сборку libcamera, поэтому ставится
# вместе с ней; остальные IPA пакета станут неподписанными, но на 6T они
# не используются
put $B/src/ipa/simple/ipa_soft_simple.so $L/libcamera/ipa/ipa_soft_simple.so 755
put $B/src/ipa/simple/ipa_soft_simple.so.sign $L/libcamera/ipa/ipa_soft_simple.so.sign 644
put $B/src/libcamera/proxy/worker/soft_ipa_proxy /usr/libexec/libcamera/soft_ipa_proxy 755
put $B/src/apps/cam/cam /usr/bin/cam 755
# Файл настройки IPA: алгоритм Af в списке (из патча 0001)
put $B/../src/ipa/simple/data/uncalibrated.yaml /usr/share/libcamera/ipa/simple/uncalibrated.yaml 644
# Настройки IPA по матрицам: IMX519 с цветовыми матрицами (патч 0015),
# IMX371 и IMX376 с потолком усиления 8× (патч 0017)
for m in imx371 imx376 imx519; do
	install -m 644 $B/../src/ipa/simple/data/$m.yaml /usr/share/libcamera/ipa/simple/$m.yaml
done
ln -sf libcamera.so.0.7.2 $L/libcamera.so.0.7
ln -sf libcamera-base.so.0.7.2 $L/libcamera-base.so.0.7
