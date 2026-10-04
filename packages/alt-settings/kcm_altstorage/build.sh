#!/bin/sh
# Сборка kcm_altstorage на телефоне, лог в /home/altlinux/altstorage.log
exec > /home/altlinux/altstorage.log 2>&1
cd /home/altlinux/alt-settings/kcm_altstorage
mkdir -p build && cd build
[ -f Makefile ] || cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DKDE_INSTALL_USE_QT_SYS_PATHS=ON -DKDE_INSTALL_LIBDIR=lib64
echo "cmake rc=$?"
make -j2; echo "make rc=$?"
