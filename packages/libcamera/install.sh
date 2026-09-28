#!/bin/sh
# Установка libcamera 0.7.2 с патчами этого каталога поверх пакета ALT, от
# root. Сборка на телефоне заранее (см. README.md), дерево в $B.
# Оригиналы сохраняются рядом с суффиксом .orig; откат: uninstall.sh.
set -e
B=${1:-/home/altlinux/libcamera-af/build}
put() { # $1 источник, $2 цель
	[ -f "$2.orig" ] || cp -a "$2" "$2.orig"
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
/sbin/ldconfig
