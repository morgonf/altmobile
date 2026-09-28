#!/bin/sh
# Вернуть файлы libcamera из пакета ALT (копии .orig от install.sh), от root
for f in /usr/lib64/libcamera.so.0.7.2 /usr/lib64/libcamera-base.so.0.7.2 \
	/usr/lib64/libcamera/ipa/ipa_soft_simple.so /usr/lib64/libcamera/ipa/ipa_soft_simple.so.sign \
	/usr/libexec/libcamera/soft_ipa_proxy /usr/bin/cam /usr/share/libcamera/ipa/simple/uncalibrated.yaml; do
	[ -f "$f.orig" ] && mv -f "$f.orig" "$f"
done
/sbin/ldconfig
