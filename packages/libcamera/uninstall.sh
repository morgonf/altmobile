#!/bin/sh
# Вернуть файлы libcamera из пакета ALT (копии от install.sh), от root
O=/usr/lib64/libcamera-alt-orig
for b in $O/*; do
	[ -f "$b" ] || continue
	f=$(basename "$b" | tr _ /)
	mv -f "$b" "$f"
done
ln -sf libcamera.so.0.7.2 /usr/lib64/libcamera.so.0.7
ln -sf libcamera-base.so.0.7.2 /usr/lib64/libcamera-base.so.0.7
